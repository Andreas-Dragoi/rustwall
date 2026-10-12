extends Node3D
## Der Held: freie Bewegung (ohne Physik-Körper, Kollision über das Raster), automatisches Zielen,
## 18 Waffen in sieben Feuerarten, Fähigkeiten, Fahrzeug, Leben mit Erholung.

const D = preload("res://src/data.gd")
const MK = preload("res://src/mk.gd")
const Humanoid = preload("res://src/humanoid.gd")
const LO = preload("res://src/liveops.gd")                 # Paket L: Skins, Albtraum+
const Models = preload("res://src/models.gd")
const Skills = preload("res://src/skills.gd")
const Tower = preload("res://src/tower.gd")
const Arsenal = preload("res://src/arsenal.gd")

const SEAT := {"quad": Vector3(0, 0.75, -0.3), "bike": Vector3(-0.3, 0.8, -0.2), "buggy": Vector3(0, 0.6, -0.2), "pickup": Vector3(0, 0.95, 0.7), "hover": Vector3(0, 0.7, 0.2)}

var key := "jona"
var body: Node3D
var alive := true
var hidden := false                  # Rauchfeder: Gegner sehen den Helden nicht
var hp := 100.0
var max_hp := 100.0
var base_speed := 5.5
var vel := Vector3.ZERO
var speed_now := 0.0
var deaths := 0
var m := {}                          # Talent-/Ausrüstungswerte aus P.hero_stats
var level := 1
var pickup_mult := 1.0
var skills: RefCounted

var weapon: Dictionary
var weapon_key := ""
var dmg := 1.0                       # fertiger Schaden pro Treffer
var rpm := 100.0
var mag := 10.0
var reload_time := 2.0
var wrange := 10.0
var crit := 0.0
var double_chance := 0.0
var ammo := 0.0
var reloading := false

# Zustände, die Fähigkeiten setzen
var invuln := 0.0
var dr := 0.0                        # Schadensminderung 0..1
var dr_t := 0.0
var rate_k := 1.0
var rate_t := 0.0
var speed_k := 1.0
var speed_t := 0.0
var dash_t := 0.0
var dash_dir := Vector2.ZERO
var burn_aura := 0.0

# Fahrzeug
var veh_key := ""
var veh_node: Node3D
var _wheels: Array = []
var _fan: Node3D
var _seat := Vector3(0, 0.75, -0.3)
var _veh_roll := 0.0
var _prev_speed := 0.0
var veh_hp := 0.0
var veh_max := 0.0
var veh_speed := 1.0
var mounted := false
var hover := false

var _vel := Vector2.ZERO
var _facing := Vector2(0, 1)
var _target = null
var _aim := Vector2.ZERO
var _think := 0.0
var _crowd := 0
var _cool := 0.0
var _reload_t := 0.0
var _idle_t := 0.0
var _since_hit := 99.0
var _respawn := 0.0
var _flame: CPUParticles3D
var _tick := 0.0
var _shots := 0
var _rng := RandomNumberGenerator.new()
var _step_t := 0.0
var _dodge_cd := 0.0
var dodge_max := 1               # ab Heldenstufe 3 zwei Ladungen
var test_wish = null             # Tests: erzwungene Laufrichtung (Vector2)
var dodge_n := 1
var _ram_t := 0.0
var _veh_yaw := 0.0
var _bot_stuck := 0.0
var _bot_side_t := 0.0
var _bot_side := 1.0
var _aura_t := 0.0
var _hit_t := 0.0                    # Abstand zwischen zwei Treffer-Animationen
var _heart_t := 0.0
var _step_snd := "step_grass"
var _eng_snd := ""
var arsenal: Node3D               # neue Schussarten (arsenal.gd)
var _charge := 0.0                   # Aufladen (Schussart charge)
signal died
signal respawned


func setup(hero_key: String) -> void:
	key = hero_key
	var def: Dictionary = D.HEROES[key]
	var st: Dictionary = P.hero_stats(key)
	m = st.m
	level = int(st.level)
	max_hp = st.hp
	hp = max_hp
	base_speed = st.speed
	pickup_mult = 1.0 + float(m.pickup)
	dodge_max = 2 if level >= D.HERO_DODGE2_LEVEL else 1
	dodge_n = dodge_max
	body = Humanoid.new()
	add_child(body)
	body.build({"helm": def.color, "suit": def.suit, "kind": key, "tier": clampi(int(level / 8), 0, 3), "skin": LO.hero_skin(key)})     # Paket L: Helden-Skin
	body.scale = Vector3.ONE * D.CHAR_SCALE
	body.footstep.connect(_on_footstep)
	arsenal = Arsenal.new()
	if G.game != null:
		G.game.add_child(arsenal)
	else:
		add_child(arsenal)
	arsenal.setup(self)
	var it: Dictionary = P.item(int(P.hero(key).weapon))
	set_weapon(it)
	skills = Skills.new(self)
	if G.game != null:
		_step_snd = Sfx.ground(G.game.theme)
	G.skill_pressed.connect(_on_skill)
	G.dodge_pressed.connect(dodge)
	G.use_pressed.connect(toggle_vehicle)


func set_weapon(it: Dictionary) -> void:
	weapon_key = it.get("key", D.HEROES[key].weapons[0])
	weapon = D.WEAPONS[weapon_key]
	var wm := P.weapon_mult(it) if not it.is_empty() else 1.0
	dmg = float(weapon.damage) * wm * (1.0 + float(m.dmg)) * (1.0 + P.item_mod(it, "damage"))
	rpm = float(weapon.rpm) * (1.0 + P.item_mod(it, "rpm"))
	mag = ceilf(float(weapon.mag) * (1.0 + P.item_mod(it, "mag")))
	reload_time = float(weapon.reload) * maxf(0.4, 1.0 - float(m.reload) - P.item_mod(it, "reload"))
	wrange = float(weapon.range) * (1.0 + float(m.range) + P.item_mod(it, "range"))
	crit = float(m.crit) + P.item_mod(it, "crit") + float(weapon.get("crit", 0.0))
	double_chance = P.item_mod(it, "double")
	ammo = mag
	reloading = false
	_charge = 0.0
	_cool = minf(_cool, 0.3)                 # Abklingzeit der alten Waffe nicht mitnehmen
	if arsenal != null:
		arsenal.beam_off()
		arsenal.charge_glow(0.0, Color.WHITE)
	body.set_weapon(LO.tint_weapon(Models.weapon(weapon_key)), weapon.len)      # Paket L: Waffen-Skin
	body.set_pose(weapon_key)
	body.two_handed = true
	if _flame:
		_flame.queue_free()
		_flame = null
	if weapon.mode == "cone":
		_flame = G.fx.make_flame(body.muzzle, wrange)
		if weapon.get("water", false):
			var grad := Gradient.new()
			grad.set_color(0, Color(0.8, 0.95, 1.0, 1.0))
			grad.set_color(1, Color(0.3, 0.6, 1.0, 0.0))
			_flame.color_ramp = grad
			_flame.gravity = Vector3(0, -3.0, 0)
		else:
			# V4: Frost, Teer, Dampf, Wind bekommen eigene Farben
			var cols := {"frost": [Color(0.9, 1.0, 1.0, 1.0), Color(0.5, 0.8, 1.0, 0.0)], "tar": [Color(0.35, 0.2, 0.1, 1.0), Color(1.0, 0.5, 0.1, 0.0)],
				"steam": [Color(1, 1, 1, 0.9), Color(0.85, 0.9, 1.0, 0.0)], "wind": [Color(1, 1, 1, 0.6), Color(0.8, 1.0, 0.9, 0.0)]}
			for fk in cols:
				if weapon.get(fk, false):
					var gr := Gradient.new()
					gr.set_color(0, cols[fk][0])
					gr.set_color(1, cols[fk][1])
					_flame.color_ramp = gr


func pos2() -> Vector2:
	return Vector2(global_position.x, global_position.z)


func facing() -> Vector2:
	return _facing


func respawn_left() -> float:
	return _respawn


func ammo_ratio() -> float:
	if reloading:
		return 1.0 - _reload_t / maxf(reload_time, 0.01)
	return ammo / mag if mag > 0.0 else 1.0


func skill_scale() -> float:
	return (1.0 + 0.06 * (level - 1)) * (1.0 + float(m.dmg) * 0.5)


func _on_skill(slot: int) -> void:
	if alive and G.game != null and G.game.is_running() and not G.main.ui_blocked():
		skills.use(slot)


# ---------------------------------------------------------------- Fahrzeug
func give_vehicle(vk: String) -> void:
	if vk == "":
		return
	veh_key = vk
	var vs: Dictionary = P.vehicle_stats(vk)
	veh_max = vs.hp
	veh_hp = veh_max
	veh_speed = vs.speed
	veh_node = Models.vehicle(vk)
	veh_node.scale = Vector3.ONE * 1.15
	_eng_snd = "engine_" + vk
	add_child(veh_node)
	_wheels.clear()
	for c in veh_node.get_children():
		if String(c.name).begins_with("wheel_"):
			_wheels.append(c)
	_fan = Models.find(veh_node, "fan")
	_seat = SEAT[vk]
	var seat_n := Models.find(veh_node, "seat")
	if seat_n != null:
		_seat = seat_n.position - Vector3(0, 0.12, 0)
	if D.VEHICLES[vk].get("turret", false):
		var t := Tower.new()
		veh_node.add_child(t)
		t.position = Vector3(0, 1.3, -1.0)
		var tn := Models.find(veh_node, "turret")
		if tn != null:
			t.position = tn.position
		t.scale = Vector3.ONE * 0.45
		t.setup("mg", 1)
		t.dmg_mult = skill_scale() * 1.5
	mount()


func mount() -> void:
	if veh_node == null or veh_hp <= 0.0 or not alive:
		return
	mounted = true
	hover = D.VEHICLES[veh_key].get("water", false)
	veh_node.top_level = false
	veh_node.position = Vector3.ZERO
	veh_node.visible = true
	Sfx.play("veh_mount", -6.0)


func dismount() -> void:
	if not mounted:
		return
	# auf Wasser kann man nicht absteigen
	if G.field.blocks_player(pos2(), false):
		P.toast.emit("Hier kannst du nicht absteigen")
		return
	mounted = false
	hover = false
	Sfx.play("veh_dismount", -8.0)
	body.position = Vector3.ZERO
	var gp := veh_node.global_transform
	veh_node.top_level = true
	veh_node.global_transform = gp


func toggle_vehicle() -> void:
	if veh_node == null or not alive or G.main.ui_blocked():
		return
	if mounted:
		dismount()
	elif veh_hp > 0.0 and veh_node.global_position.distance_to(global_position) < 5.0:
		mount()
	elif veh_hp > 0.0:
		P.toast.emit("Geh näher an dein Fahrzeug")


func vehicle_pos():
	if veh_node != null and not mounted and veh_hp > 0.0:
		return veh_node.global_position
	return null


# ---------------------------------------------------------------- Hauptschleife
func _physics_process(dt: float) -> void:
	if G.game == null:
		return
	if not G.game.is_active():
		body.move_amount = 0.0
		body.aiming = false
		body.tick(dt)
		vel = Vector3.ZERO
		if _flame:
			_flame.emitting = false
		return
	if not alive:
		_respawn -= dt
		body.tick(dt)
		if _respawn <= 0.0 and G.game.can_respawn():
			_do_respawn()
		return
	if _dodge_cd > 0.0:
		_dodge_cd = maxf(0.0, _dodge_cd - dt)
		if _dodge_cd <= 0.0 and dodge_n < dodge_max:
			dodge_n += 1
			if dodge_n < dodge_max:
				_dodge_cd = 3.0
	invuln = maxf(0.0, invuln - dt)
	_hit_t = maxf(0.0, _hit_t - dt)
	_since_hit += dt
	if dr_t > 0.0:
		dr_t -= dt
		if dr_t <= 0.0:
			dr = 0.0
	if rate_t > 0.0:
		rate_t -= dt
		if rate_t <= 0.0:
			rate_k = 1.0
	if speed_t > 0.0:
		speed_t -= dt
		if speed_t <= 0.0:
			speed_k = 1.0
			hidden = false
	if burn_aura > 0.0:
		burn_aura -= dt
		_aura_t -= dt
		if _aura_t <= 0.0:
			_aura_t = 0.5
			for e in G.horde.in_radius(pos2(), 3.5):
				e.burn = maxf(e.burn, 3.0)
			G.fx.ring(global_position, 3.5, Color(1.0, 0.5, 0.1), 0.4)
	if _since_hit > 5.0 and hp < max_hp and not LO.nm_noheal:      # Paket L: Albtraum+ „Keine Heilung“
		hp = minf(max_hp, hp + max_hp * 0.03 * dt)
	if hp < max_hp * 0.3:                # leiser Herzschlag bei wenig Leben
		_heart_t -= dt
		if _heart_t <= 0.0:
			_heart_t = 0.9
			Sfx.play("heartbeat", -9.0)
	if mounted:                          # Motor: Tonhöhe und Lautstärke folgen dem Tempo
		var ek := clampf(speed_now / maxf(base_speed * veh_speed, 0.1), 0.0, 1.2)
		Sfx.loop("engine", _eng_snd, -17.0 + 5.0 * ek, 0.75 + 0.6 * ek, 0.3)
	skills.tick(dt)
	_move(dt)
	if G.game.is_running():
		_combat(dt)
	else:
		_target = null
		_aim = Vector2.ZERO
		if _flame:
			_flame.emitting = false
		if arsenal != null:
			arsenal.beam_off()
			arsenal.charge_glow(0.0, Color.WHITE)
		if ammo < mag and not reloading and mag > 0.0:
			ammo = mag
	var want := _facing
	if _aim != Vector2.ZERO:
		want = _aim
	elif _vel.length() > 0.4:
		want = _vel.normalized()
	_facing = want
	body.rotation.y = lerp_angle(body.rotation.y, atan2(want.x, want.y), minf(1.0, dt * 14.0))
	if mounted:
		if _vel.length() > 0.5:
			_veh_yaw = lerp_angle(_veh_yaw, atan2(_vel.x, _vel.y), minf(1.0, dt * 7.0))
		var before_yaw := veh_node.rotation.y
		veh_node.rotation.y = _veh_yaw
		# Räder drehen, Karosserie wippt und legt sich in die Kurve
		var spin := speed_now * dt / 0.5
		for w in _wheels:
			w.rotate_object_local(Vector3.RIGHT, spin)
		if _fan != null:
			_fan.rotate_object_local(Vector3.BACK, dt * (10.0 + speed_now * 3.0))
		var turn := angle_difference(before_yaw, _veh_yaw) / maxf(dt, 0.001)
		_veh_roll = lerpf(_veh_roll, clampf(-turn * 0.06, -0.2, 0.2), minf(1.0, dt * 6.0))
		var tsec := Time.get_ticks_msec() * 0.001
		veh_node.rotation.z = _veh_roll
		veh_node.rotation.x = clampf((speed_now - _prev_speed) * -0.02, -0.12, 0.12)
		veh_node.position.y = absf(sin(tsec * (6.0 + speed_now))) * 0.04 * clampf(speed_now / 4.0, 0.2, 1.0) + (0.12 + sin(tsec * 3.0) * 0.06 if hover else 0.0)
		_prev_speed = lerpf(_prev_speed, speed_now, minf(1.0, dt * 5.0))
		var seat: Vector3 = _seat * 1.15
		body.position = Basis(Vector3.UP, _veh_yaw) * seat + Vector3(0, veh_node.position.y, 0)
		body.move_amount = 0.0
		body.kneel = 0.75
		body.ride = veh_key
		body.speed_mps = 0.0
	else:
		body.ride = ""
		body.move_amount = speed_now / 6.4
		body.speed_mps = speed_now
		if _vel.length() > 0.1:          # Laufrichtung relativ zur Blickrichtung der Figur (rückwärts/seitwärts laufen)
			var by: float = body.rotation.y
			body.move_dir = Vector2(_vel.dot(Vector2(cos(by), -sin(by))), _vel.dot(Vector2(sin(by), cos(by)))).normalized()
		body.lean = lerpf(body.lean, clampf((speed_now - _prev_speed) * 0.25, -1.0, 1.0), minf(1.0, dt * 8.0))
		_prev_speed = lerpf(_prev_speed, speed_now, minf(1.0, dt * 6.0))
		body.kneel = move_toward(body.kneel, 0.0, dt * 6.0)
	body.aiming = _aim != Vector2.ZERO or reloading
	if _aim == Vector2.ZERO:
		body.look_target = null
	elif _target != null:
		body.look_target = Vector3(_target.p.x, 0.5 * float(_target.sc), _target.p.y)
	else:
		body.look_target = global_position + Vector3(_aim.x * 9.0, 0.9, _aim.y * 9.0)
	body.tick(dt)
	body.visible = (invuln <= 0.0 or fmod(invuln, 0.2) > 0.08)
	if hidden:
		body.visible = fmod(Time.get_ticks_msec() * 0.001, 0.3) > 0.15


func _move(dt: float) -> void:
	var wish := Vector2.ZERO
	if test_wish != null:
		wish = test_wish
	elif G.autotest != "":
		wish = _bot_wish(dt)
	elif not G.main.ui_blocked() and not G.game.hero_locked():
		var iv := G.move_vector()
		wish = G.cam.screen_to_world_dir(iv)
		if not G.is_touch and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and iv == Vector2.ZERO and not G.main.pointer_over_ui():
			var mp = G.cam.mouse_ground()
			if mp != null:
				var to: Vector2 = Vector2(mp.x, mp.z) - pos2()
				if to.length() > 0.6:
					wish = to.normalized()
	var top := base_speed * speed_k * (2.0 if G.ch("fast") else 1.0)
	if mounted:
		top = base_speed * veh_speed
	else:
		top *= 1.0 - 0.35 * clampf(_crowd / 6.0, 0.0, 1.0)
	if dash_t > 0.0:
		dash_t -= dt
		_vel = dash_dir * base_speed * 3.2
	else:
		var rate := top / (0.25 if mounted else 0.1)
		_vel = _vel.move_toward(wish * top, maxf(rate, 30.0) * dt)
	var before := pos2()
	var field = G.field
	var rad := 0.5 if mounted else 0.45
	# in kleinen Teilschritten bewegen: auch bei hohem Tempo (Rolle, Fahrzeug, Zeitraffer) springt nichts durch eine Mauer
	var move := _vel * dt
	var parts := clampi(int(ceil(move.length() / 0.4)), 1, 24)
	var np := before
	for i in parts:
		var from := np
		var to := from + move / float(parts)
		if _blocked(field, to, rad):
			var nx := Vector2(to.x, from.y)
			var nz := Vector2(from.x, to.y)
			if not _blocked(field, nx, rad):
				to = nx
			elif not _blocked(field, nz, rad):
				to = nz
			else:
				# steckt der Held fest (frisch gebautes Gebäude), darf er hinauslaufen
				if not _blocked(field, from, 0.0):
					break
		np = to
	global_position = Vector3(np.x, 0.0, np.y)
	var moved := (np - before).length()
	speed_now = moved / maxf(dt, 0.0001)
	vel = Vector3(_vel.x, 0, _vel.y) if moved > 0.001 else Vector3.ZERO
	if speed_now > 2.0 and mounted:          # zu Fuß kommen Schritt-Ton und Staub aus der Animation (_on_footstep)
		_step_t -= dt * speed_now
		if _step_t <= 0.0:
			_step_t = 1.6
			G.fx.puff(global_position + Vector3(0, 0.05, 0), Color(0.85, 0.78, 0.6, 0.8), 6, 0.4)
	if mounted and D.VEHICLES[veh_key].get("ram", false) and speed_now > 4.0:
		_ram_t -= dt
		if _ram_t <= 0.0:
			_ram_t = 0.15
			for e in G.horde.in_radius(np, 1.9):
				if e.r < 0.6:
					Sfx.play("ram_bump", -9.0, 1.0, 0.12)
					G.horde.knock(e, (_vel.normalized() + (e.p - np).normalized()).normalized(), 1.6)
					G.horde.damage(e, 14.0 * skill_scale(), _vel.normalized(), false, false, "kugel")


## Schritt aus der Lauf-Animation (Ereignisse foot_l / foot_r): Klang des Untergrunds und kleine Staubwolke.
func _on_footstep(left: bool) -> void:
	if not alive or mounted or dash_t > 0.0 or speed_now < 1.0 or G.game == null or not G.game.is_active():
		return
	Sfx.play(_step_snd, -19.0 if speed_now > 2.5 else -23.0, 1.0 if left else 1.06, 0.12)
	if speed_now > 2.0:
		var side := Vector3(cos(body.rotation.y), 0, -sin(body.rotation.y)) * (-0.22 if left else 0.22)
		G.fx.puff(global_position + side + Vector3(0, 0.05, 0), Color(0.85, 0.78, 0.6, 0.8), 2, 0.4)


func _blocked(field, p: Vector2, rad: float) -> bool:
	if field.blocks_player(p, hover):
		return true
	if rad <= 0.0:
		return false
	return field.blocks_player(p + Vector2(rad, 0), hover) or field.blocks_player(p - Vector2(rad, 0), hover) \
		or field.blocks_player(p + Vector2(0, rad), hover) or field.blocks_player(p - Vector2(0, rad), hover)


func dodge() -> void:
	if not alive or dodge_n <= 0 or dash_t > 0.0 or mounted or G.game == null or not G.game.is_active() or G.main.ui_blocked():
		return
	dodge_n -= 1
	if _dodge_cd <= 0.0:
		_dodge_cd = 3.0
	Sfx.play("dash", -8.0)
	start_dash(0.2, 0.3)


func start_dash(time: float, safe: float) -> void:
	dash_dir = _vel.normalized() if _vel.length() > 0.5 else _facing
	dash_t = time
	invuln = maxf(invuln, safe)
	body.hop(time + 0.1)
	G.fx.puff(global_position + Vector3(0, 0.2, 0), Color(0.9, 0.85, 0.7), 8)


func dodge_ratio() -> float:
	return 1.0 if dodge_n > 0 else 1.0 - _dodge_cd / 3.0


## Liest Stufe, Werte und Freischaltungen neu ein (nach einem Stufenaufstieg im Kampf).
func refresh_stats() -> void:
	var st: Dictionary = P.hero_stats(key)
	var ratio := hp / maxf(max_hp, 1.0)
	m = st.m
	level = int(st.level)
	max_hp = st.hp
	hp = max_hp * ratio
	base_speed = st.speed
	pickup_mult = 1.0 + float(m.pickup)
	dodge_max = 2 if level >= D.HERO_DODGE2_LEVEL else 1
	var it: Dictionary = P.item(int(P.hero(key).weapon))
	var am := ammo
	set_weapon(it)
	ammo = minf(am, mag) if am > 0.0 else mag
	if skills != null:
		for i in 3:
			skills.slots[i].locked = level < skills.UNLOCK[i]


# ---------------------------------------------------------------- Kampf
func _combat(dt: float) -> void:
	var horde = G.horde
	var pp := pos2()
	_think -= dt
	if _think <= 0.0:
		_think = 0.1
		_target = horde.nearest(pp, wrange, 0.0, weapon.get("elite", false))
		_crowd = horde.in_radius(pp, 1.4).size()
	if _target != null and _target.st == 2:
		_target = null
		_think = 0.0
	_aim = Vector2.ZERO
	var manual := false
	if not G.is_touch and G.autotest == "" and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not G.main.pointer_over_ui() and not G.main.ui_blocked():
		var mp = G.cam.mouse_ground()
		if mp != null:
			var to: Vector2 = Vector2(mp.x, mp.z) - pp
			if to.length() > 0.3:
				_aim = to.normalized()
				manual = true
	if not manual and _target != null:
		var to2: Vector2 = _target.p - pp
		if to2.length() > 0.01:
			_aim = to2.normalized()
	var rate := rate_k
	if G.ch("ammo"):
		ammo = mag
		reloading = false
	_cool -= dt * rate
	var firing_cone := false
	var firing_beam := false
	if reloading:
		_reload_t -= dt
		if _reload_t <= 0.0:
			reloading = false
			ammo = mag
			Sfx.play("reload_done", -10.0)
	elif _aim == Vector2.ZERO:
		if weapon.mode == "charge" and _charge > 0.0:
			if _charge >= float(weapon.charge) * 0.3:       # Ziel verloren: halb geladenen Schuss lösen
				_release_charge(pp, _facing)
			_charge = 0.0
		_idle_t += dt
		if _idle_t > 1.2 and ammo < mag and mag > 0.0:
			_start_reload()
		_cool = maxf(_cool, 0.0)
	else:
		_idle_t = 0.0
		if ammo <= 0.0 and mag > 0.0:
			Sfx.play("empty", -10.0)
			_start_reload()
		elif weapon.mode == "cone":
			firing_cone = true
			_tick -= dt
			ammo -= rpm / 60.0 * dt
			if _tick <= 0.0:
				_tick = 0.1
				var d: float = dmg * rpm / 60.0 * 0.1 * rate
				for e in horde.cone(pp, _aim, wrange, weapon.cone * 0.5):
					if weapon.has("burn"):
						e.burn = maxf(e.burn, weapon.burn)
						e.burn_d = 5.0 * skill_scale() * (1.0 + float(m.burn))
					if weapon.has("slow"):
						e.slow = maxf(e.slow, weapon.slow)
					if weapon.has("knock"):
						horde.knock(e, _aim, weapon.knock * 0.25)
					if weapon.has("freeze") and _rng.randf() < float(weapon.freeze) and horde.weak_of(e, "eis") > 0.0:
						e.stun = maxf(e.stun, 0.8)
					horde.damage(e, d, _aim, false, true, weapon.get("element", ""))
		elif weapon.mode == "beam":
			firing_beam = true
			ammo -= rpm / 60.0 * dt
			arsenal.beam_tick(weapon, dmg, pp, _aim, body.muzzle.global_position, dt, rate)
		elif weapon.mode == "charge":
			_charge += dt * rate
			var full: float = weapon.charge
			arsenal.charge_glow(minf(_charge / full, 1.0), Arsenal.el_col(weapon))
			if Sfx.has("w_charge_loop"):
				Sfx.loop("hero_charge", "w_charge_loop", -12.0, 0.8 + 0.6 * minf(_charge / full, 1.0), 0.2)
			if _charge >= full and _cool <= 0.0:
				_release_charge(pp, _aim)
		else:
			var guard := 0
			while _cool <= 0.0 and (ammo > 0.0 or mag <= 0.0) and guard < 3:
				_cool += 60.0 / rpm
				if mag > 0.0 and _rng.randf() >= double_chance:
					ammo -= 1.0
				guard += 1
				_shoot(pp)
			_cool = maxf(_cool, -0.05)
	if _flame:
		_flame.emitting = firing_cone
	if firing_cone:                      # Flammen-/Wasserwerfer: Schleife, endet von selbst
		Sfx.loop("hero_cone", Arsenal.snd(weapon), -9.0, 1.0, 0.25)
	if firing_beam:
		Sfx.loop("hero_cone", Arsenal.snd(weapon), -10.0, 1.0, 0.25)
		if fmod(Time.get_ticks_msec() * 0.001, 0.5) < dt:
			body.kick(0.3)
	elif arsenal != null and weapon.mode == "beam":
		arsenal.beam_off()
	if weapon.mode == "charge" and (_charge <= 0.0 or reloading):
		arsenal.charge_glow(0.0, Color.WHITE)


## Aufgeladener Schuss (Schussart charge): je länger geladen, desto stärker (ab 30 %).
func _release_charge(pp: Vector2, dir: Vector2) -> void:
	var k := clampf(_charge / float(weapon.charge), 0.0, 1.0)
	_charge = 0.0
	_cool = 60.0 / rpm
	if mag > 0.0:
		ammo -= 1.0
	_shots += 1
	body.kick(1.0)
	Sfx.play(Arsenal.snd(weapon), -5.0, 1.15 - 0.2 * k)
	arsenal.charge_glow(0.0, Color.WHITE)
	arsenal.charge_fire(weapon, dmg, k, pp, dir, body.muzzle.global_position, _target)


func _start_reload() -> void:
	_charge = 0.0
	reloading = true
	_reload_t = reload_time
	body.reload(reload_time)
	Sfx.play("reload", -10.0)


func refill() -> void:
	reloading = false
	ammo = mag


func _hit(e, d: float, dir: Vector2) -> void:
	if crit > 0.0 and _rng.randf() < crit:
		d *= 2.0
		Sfx.play("crit", -9.0, 1.0, 0.1)
		G.fx.float_text(Vector3(e.p.x, 1.6 * e.sc, e.p.y), "Volltreffer!", Color("FFD23E"))
	if weapon.has("knock"):
		G.horde.knock(e, dir, weapon.knock)
	if weapon.get("shrink", false):
		e.shrink = 3.0
	# V4: Wirkungen der neuen Waffen
	if weapon.has("pull"):
		G.horde.knock(e, (pos2() - e.p).normalized(), float(weapon.pull))
	if weapon.has("burn") and weapon.mode != "cone":
		e.burn = maxf(e.burn, float(weapon.burn))
		e.burn_d = 5.0 * skill_scale() * (1.0 + float(m.burn))
	if weapon.has("poison"):
		e.poison = maxf(e.poison, float(weapon.poison))
	if weapon.has("chill"):
		e.slow = maxf(e.slow, float(weapon.chill))
	if weapon.has("freeze") and _rng.randf() < float(weapon.freeze) and G.horde.weak_of(e, "eis") > 0.0:
		e.stun = maxf(e.stun, 1.0)
		G.fx.puff(Vector3(e.p.x, 0.6 * e.sc, e.p.y), Color(0.75, 0.95, 1.0), 6, 0.6)
	if weapon.has("stun_ch") and _rng.randf() < float(weapon.stun_ch):
		e.stun = maxf(e.stun, float(weapon.get("stun", 0.8)))
	if weapon.has("leech"):
		heal(d * float(weapon.leech))
	G.fx.splat(Vector3(e.p.x, 0.5 * e.sc, e.p.y), Color(0.7, 0.85, 0.25))
	G.horde.damage(e, d, dir, false, false, weapon.get("element", ""))


func _shoot(pp: Vector2) -> void:
	var horde = G.horde
	var muzzle: Vector3 = body.muzzle.global_position
	var m2 := Vector2(muzzle.x, muzzle.z)
	_shots += 1
	body.kick(1.0 if rpm < 300 else 0.5)
	Sfx.play(Arsenal.snd(weapon), -7.0)
	var aim3 := Vector3(_aim.x, 0, _aim.y)
	if weapon.has("recoil"):                 # Rückstoß-Sprung
		push(-_aim, float(weapon.recoil))
	match weapon.mode:
		"hitscan":
			var arrow: bool = weapon.get("arrow", false)
			var beam: bool = weapon.get("beam", false)
			if not arrow and not beam:
				G.fx.flash(muzzle, aim3, 1.0 if rpm > 200 else 1.6, true)
			var col := Color(1, 0.9, 0.55)
			if weapon.has("beam_col"):
				col = Color(String(weapon.beam_col))
			elif weapon.get("candy", false):
				col = Color(1.0, 0.5, 0.8)
			elif beam:
				col = Color(0.6, 1.0, 0.7)
			elif arrow:
				col = Color(1, 1, 1)
			var mark_shot: bool = weapon.has("mark_every") and _shots % int(weapon.mark_every) == 0
			for i in int(weapon.get("pellets", 1)):
				var sp := deg_to_rad(_rng.randf_range(-weapon.spread, weapon.spread))
				var dir := _aim.rotated(sp)
				var hits: Array = horde.ray(pp, dir, wrange, 1 + int(weapon.pierce))
				var end: Vector2 = m2 + dir * wrange
				for h in hits:
					var e = h[1]
					if mark_shot:
						e.mark = maxf(e.mark, 4.0)
					_hit(e, dmg, dir)
				if hits.size() >= 1 + int(weapon.pierce):
					end = hits[hits.size() - 1][1].p
				G.fx.tracer(muzzle, Vector3(end.x, muzzle.y * 0.6, end.y), col, 0.1 if beam else 0.06, 0.1 if arrow else 0.06)
		"proj":
			var tp := pp + _aim * minf(wrange, 11.0)
			if _target != null:
				tp = _target.p + _target.v * 0.4
			var to := Vector3(tp.x, 0.1, tp.y)
			var w := weapon
			var d := dmg
			var pc: Color = D.HEROES[key].color if not w.has("lvl") else Arsenal.el_col(w)
			G.game.launch(muzzle, to, clampf(muzzle.distance_to(to) / 22.0, 0.3, 0.7), 3.0, pc, func(): _proj_land(to, w, d))
		"homing":
			var tp2 := pp + _aim * minf(wrange, 11.0)
			if _target != null:
				tp2 = _target.p
			var to2 := Vector3(tp2.x, 0.3, tp2.y)
			var spl: float = weapon.splash
			var d2 := dmg
			G.game.launch(muzzle, to2, clampf(muzzle.distance_to(to2) / 26.0, 0.2, 0.8), 1.5, Color(1.0, 0.9, 0.5), func(): G.game.blast(to2, spl, d2, {}, Color(1.0, 0.7, 0.9)), true)
		"chain":
			var cur = _target
			if cur == null:
				var hits2: Array = horde.ray(pp, _aim, wrange, 1, 0.6)
				if hits2.size() > 0:
					cur = hits2[0][1]
			var prev := muzzle
			if cur == null:
				G.fx.lightning(muzzle, muzzle + aim3 * wrange * 0.6)
			var done: Array = []
			for i in int(weapon.chain):
				if cur == null:
					break
				done.append(cur)
				var cp := Vector3(cur.p.x, 0.5 * cur.sc, cur.p.y)
				G.fx.lightning(prev, cp)
				_hit(cur, dmg, Vector2.ZERO)
				prev = cp
				var nxt = null
				var bd := 25.0
				for o in horde.in_radius(cur.p, 5.0):
					if not done.has(o):
						var dd: float = o.p.distance_squared_to(cur.p)
						if dd < bd:
							bd = dd
							nxt = o
				cur = nxt
		"swing":
			body.swing()
			var n := 0
			var arc: float = weapon.get("arc", 70.0)
			for e in horde.cone(pp, _aim, wrange, arc):
				if n >= (10 if arc < 150.0 else 16):
					break
				_hit(e, dmg, _aim)
				n += 1
			G.fx.ring(global_position + aim3 * 1.5, wrange * 0.8, Color(1, 1, 1, 0.5), 0.2)
			if n > 0:
				Sfx.play("w_ball_thud", -6.0)
				G.vibrate(15)
		"multi":
			var cands: Array = horde.in_radius(pp, wrange)
			cands.sort_custom(func(a, b): return a.p.distance_squared_to(pp) < b.p.distance_squared_to(pp))
			for i in mini(int(weapon.targets), cands.size()):
				var e2 = cands[i]
				G.fx.tracer(muzzle, Vector3(e2.p.x, 0.5 * e2.sc, e2.p.y), Color.WHITE, 0.05, 0.1)
				_hit(e2, dmg, (e2.p - pp).normalized())
		_:
			arsenal.shoot(weapon, weapon_key, dmg, pp, _aim, muzzle, _target)


func _proj_land(to: Vector3, w: Dictionary, d: float) -> void:
	var c := Vector2(to.x, to.z)
	var opts := {}
	if w.has("knock"):
		opts["knock"] = w.knock
	if w.has("root"):
		opts["root"] = w.root
	if w.has("slow"):
		opts["slow"] = w.slow
	for k in ["stun", "burn", "poison"]:      # V4
		if w.has(k):
			opts[k] = float(w[k])
	var spl: float = w.get("splash", 0.0)
	opts["element"] = w.get("element", "explosion")
	if w.has("root"):
		opts["sfx"] = "glue_splat"
	elif w.get("zone", "") == "heal":
		opts["sfx"] = "cake_splat"
	if spl > 0.0 and not w.get("rain", false):
		G.game.blast(to, spl, d, opts, D.HEROES[key].color.lightened(0.3) if not w.has("lvl") else Arsenal.el_col(w))
	match w.get("zone", ""):
		"fire":
			G.game.add_zone("fire", c, spl, w.zone_t, d * 0.4)
		"storm":
			G.game.add_zone("storm", c, 4.0, w.zone_t, d)
		"heal":
			G.game.add_zone("heal", c, spl, w.zone_t, 0.05 * (1.0 + float(m.heal)))
	if w.has("lvl"):                         # V4: Streubomben, Pfeilregen, Sog- und Frostflächen, Markieren
		arsenal.proj_extra(w, to, d)


# ---------------------------------------------------------------- Leben
func hurt(d: float, from = null) -> void:
	if not alive or invuln > 0.0 or G.ch("god"):
		return
	d *= 1.0 - dr
	if key == "mika" and from != null and from.burn > 0.0:
		d *= 0.65 if level >= D.HERO_PASSIVE_LEVEL else 0.75
	if mounted and veh_hp > 0.0:
		veh_hp -= d
		if veh_hp <= 0.0:
			veh_hp = 0.0
			G.fx.explosion(global_position + Vector3(0, 1, 0), 2.5)
			P.toast.emit("Fahrzeug kaputt – weiter zu Fuß!")
			Sfx.play("veh_broken", -3.0)
			mounted = false
			hover = false
			body.position = Vector3.ZERO
			veh_node.visible = false
		return
	hp -= d
	_since_hit = 0.0
	Sfx.play("hurt", -8.0, 1.0, 0.15)
	if hp > 0.0 and speed_now < 1.0 and not mounted and _hit_t <= 0.0:    # im Stand: sichtbares Zucken
		_hit_t = 0.5
		body.play("hit_heavy" if d > max_hp * 0.2 else "hit_light")
	if G.hud:
		G.hud.damage_flash()
	if hp <= 0.0:
		hp = 0.0
		alive = false
		hidden = false
		deaths += 1
		_respawn = minf(6.0 + 3.0 * (deaths - 1), 15.0)
		body.die()
		Sfx.play("hero_down", -4.0)
		if _flame:
			_flame.emitting = false
		if arsenal != null:
			arsenal.beam_off()
			arsenal.charge_glow(0.0, Color.WHITE)
		_vel = Vector2.ZERO
		vel = Vector3.ZERO
		died.emit()


func heal(v: float) -> void:
	if alive and hp < max_hp and not LO.nm_noheal:            # Paket L: Albtraum+ „Keine Heilung“
		hp = minf(max_hp, hp + v)


func _do_respawn() -> void:
	alive = true
	hp = max_hp
	invuln = 3.0
	var sp: Vector2 = G.game.respawn_point()
	global_position = Vector3(sp.x, 0, sp.y)
	body.revive()
	body.visible = true
	refill()
	G.fx.ring(global_position, 3.0, D.C_SKY, 0.6)
	Sfx.play("respawn", -6.0)
	respawned.emit()


# ---------------------------------------------------------------- Testbetrieb
func _bot_wish(dt: float) -> Vector2:
	var pp := pos2()
	var goal = G.game.bot_goal()
	if goal == null:
		return Vector2.ZERO
	var to: Vector2 = goal - pp
	if to.length() < 0.4:
		_bot_stuck = 0.0
		return Vector2.ZERO
	if _bot_side_t > 0.0:
		_bot_side_t -= dt
		return (to.normalized() * 0.3 + to.normalized().orthogonal() * _bot_side).normalized()
	if speed_now < 1.0:
		_bot_stuck += dt
		if _bot_stuck > 0.4:
			_bot_stuck = 0.0
			_bot_side_t = _rng.randf_range(0.5, 1.4)
			_bot_side = -_bot_side if _rng.randf() < 0.7 else _bot_side
	else:
		_bot_stuck = 0.0
	return to.normalized() * minf(1.0, to.length())


# ---------------------------------------------------------------- Wirkungen von Gegnern (Paket 11)
## Verlangsamt den Helden: k = Tempo-Faktor (0,5 = halb so schnell), t = Dauer in Sekunden.
func slow(k: float, t: float) -> void:
	if not alive or invuln > 0.0 or G.ch("god"):
		return
	if speed_k > 1.0 and speed_t > 0.0:
		return                           # eigener Tempo-Schub (Rauchfeder) geht vor
	speed_k = minf(speed_k, k) if speed_t > 0.0 else k
	speed_t = maxf(speed_t, t)


## Hält den Helden fest (eingefroren, festgebissen). Die Ausweichrolle funktioniert weiter.
func root(t: float) -> void:
	if not alive or invuln > 0.0 or G.ch("god") or mounted:
		return
	speed_k = 0.0
	speed_t = maxf(speed_t, t) if speed_k <= 1.0 else t
	_vel = Vector2.ZERO


## Zieht den Helden um strength Meter auf den Punkt p zu (Anker, Sog). Mauern und Gebäude halten ihn auf.
func pull_to(p: Vector2, strength: float) -> void:
	var to := p - pos2()
	var l := to.length()
	if l < 0.05:
		return
	push(to / l, minf(strength, l))


## Schiebt den Helden um strength Meter in Richtung dir (Rückstoß, Wirbelwind).
func push(dir: Vector2, strength: float) -> void:
	if not alive or G.ch("god") or dash_t > 0.0 or G.field == null:
		return
	if mounted:
		strength *= 0.4
	var from := pos2()
	var parts := clampi(int(ceil(strength / 0.3)), 1, 16)
	var np := from
	for i in parts:
		var q := np + dir * strength / float(parts)
		if _blocked(G.field, q, 0.45):
			break
		np = q
	global_position = Vector3(np.x, 0.0, np.y)
