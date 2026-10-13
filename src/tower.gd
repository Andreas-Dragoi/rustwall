extends Node3D
## Geschützturm. Verhalten und Werte kommen aus D.TOWERS; das Modell wird je Typ gebaut
## (gedrungener Steinsockel, roter Geschützkopf mit Stern – wie im Referenzbild).
## Der Kopf dreht sich zum Ziel und schießt erst, wenn er ausgerichtet ist.

const D = preload("res://src/data.gd")
const MK = preload("res://src/mk.gd")
const Models = preload("res://src/models.gd")
const Anim = preload("res://src/anim.gd")

var key := "mg"
var def: Dictionary
var level := 1
var dmg_mult := 1.0
var life := -1.0             # > 0: verschwindet nach dieser Zeit (Fähigkeiten)
var active := true
var settler := false         # Siedler mit Gewehr statt Geschütz (Verstärkung)
var head: Node3D
var pitch: Node3D
var muzzles: Array[Node3D] = []
var shots := 0
var aim := ""                # Paket F: Zielwahl je Turm ("" automatisch, near, strong, fly, boss)
var dealt := 0.0             # V6 Paket B: angerichteter Schaden (Flut-Rückblick; zählt horde.damage über horde.dmg_src)

var _target = null
var _think := 0.0
var _cool := 0.0
var _mi := 0
var _flame: CPUParticles3D
var _tick := 0.0
var _recoil := 0.0
var _pitch_z := 0.0
var _ring: MeshInstance3D
var _spin: Node3D
var _idle_ph := 0.0
var _buff_t := 0.0
var _buff_k := 1.0
var _air := 0
var _rng := RandomNumberGenerator.new()
var _anims: Array = []          # bewegte Teile des Modells (Radar, Fahne ...)
var _shell: CPUParticles3D      # Hülsenauswurf am Leerobjekt fx_shell
var _shell_t := 0.0


func setup(tower_key: String, lvl := 1) -> void:
	key = tower_key
	def = D.TOWERS[key]
	level = lvl
	muzzles.clear()
	_build_model()
	_cool = 0.3
	_air = 0
	if def.target == "air":
		_air = 2
	elif def.mode in ["cannon", "mortar", "cone", "ice"]:
		_air = 1


func pos2() -> Vector2:
	return Vector2(global_position.x, global_position.z)


func buff(k: float, t: float) -> void:
	_buff_k = maxf(k, _buff_k if _buff_t > 0.0 else 1.0)
	_buff_t = maxf(_buff_t, t)
	if G.fx:
		G.fx.ring(global_position, 2.5, Color(1.0, 0.85, 0.3), 0.5)
		Sfx.play_at("tower_buff", global_position, -9.0, 1.0, 0.25)


func show_range(v: bool) -> void:
	if v and _ring == null:
		_ring = MeshInstance3D.new()
		var tor := TorusMesh.new()
		var rr: float = float(def.range) * (G.game.tower_range_k() if G.game != null and G.game.has_method("tower_range_k") else 1.0)
		tor.inner_radius = rr - 0.12
		tor.outer_radius = rr
		tor.rings = 64
		tor.ring_segments = 3
		_ring.mesh = tor
		_ring.material_override = MK.glow(Color(1, 1, 1, 0.35), true)
		_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ring.position.y = 0.1
		add_child(_ring)
	if _ring:
		_ring.visible = v


# ---------------------------------------------------------------- Modell
func _build_model() -> void:
	if settler:
		head = Node3D.new()
		add_child(head)
		pitch = Node3D.new()
		head.add_child(pitch)
		var hm: Node3D = load("res://src/humanoid.gd").new()
		head.add_child(hm)
		hm.build({"helm": D.C_HELM_BLUE, "suit": D.C_OLIVE, "kind": "settler", "tier": 0})
		hm.scale = Vector3.ONE * D.CHAR_SCALE
		hm.set_weapon(load("res://src/models.gd").weapon("j_rifle"), 0.9)
		hm.aiming = true
		hm.tick(0.016)
		_add_muzzle(Vector3(0.3, 1.5, 1.2))
		return
	if Models.has_glb("t_" + key):
		var sc := Models.glb("t_" + key, level)
		add_child(sc)
		head = Models.find(sc, "head")
		pitch = Models.find(sc, "pitch")
		for nm in ["muzzle", "muzzle2", "muzzle3"]:
			var mz := Models.find(sc, nm)
			if mz != null:
				muzzles.append(mz)
		_spin = Models.find(sc, "pulse_orb_glow")
		_pitch_z = pitch.position.z
		_idle_ph = randf() * TAU
		# Dauer-Animationen des Modells (die Kugel pulsiert schon über _spin)
		_anims = Anim.collect(sc).filter(func(e): return e[1] != _spin)
		set_process(not _anims.is_empty())
		var sh := Models.find(sc, "fx_shell")
		if sh != null and def.mode in ["hitscan", "pierce"]:
			_shell = _make_shells(sh)
		if def.mode == "cone":
			_flame = G.fx.make_flame(muzzles[0], def.range)
			_flame.amount = 40
			_flame.spread = 18.0
		return
	var st := MK.begin()
	var stone := D.C_STONE
	var blue := D.C_BLUE_METAL
	var red := D.C_RED
	var dark := Color("2E3340")
	var steel := Color("8A94A8")
	var gold := Color("E0A82E")
	var big := key in ["cannon", "mortar", "rocket", "ice"]
	var w := 4.4 if big else 3.0
	if key == "mini":
		w = 1.2
	var base_h := 1.5 if key in ["mg", "watch", "aa", "flame"] else 0.9
	if key == "watch":
		base_h = 3.4
	if key == "mini":
		base_h = 0.5
	# Sockel
	MK.rbox(st, Vector3(0, base_h * 0.5, 0), Vector3(w, base_h, w), stone, 0.16)
	MK.rbox(st, Vector3(0, base_h + 0.1, 0), Vector3(w * 0.86, 0.24, w * 0.86), blue, 0.08)
	if key != "mini":
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				MK.rbox(st, Vector3(w * 0.44 * sx, base_h * 0.5 + 0.1, w * 0.44 * sz), Vector3(0.5, base_h + 0.3, 0.5), MK.lighten(stone, 0.85), 0.08)
		if level >= 4:
			MK.box(st, Vector3(0, base_h * 0.55, w * 0.5 + 0.02), Vector3(w * 0.5, 0.24, 0.06), gold)
			MK.box(st, Vector3(0, base_h * 0.55, -w * 0.5 - 0.02), Vector3(w * 0.5, 0.24, 0.06), gold)
		if level >= 7:
			MK.rbox(st, Vector3(0, base_h + 0.26, 0), Vector3(w * 0.9, 0.1, w * 0.9), gold, 0.04)
	MK.inst(st, self)
	head = Node3D.new()
	head.position = Vector3(0, base_h + 0.22, 0)
	add_child(head)
	pitch = Node3D.new()
	head.add_child(pitch)
	var hs := MK.begin()
	var ps := MK.begin()
	match key:
		"mg", "aa":
			pitch.position = Vector3(0, 0.75, 0.1)
			MK.cyl(hs, Vector3.ZERO, 0.55, 0.45, 0.4, 10, dark)
			MK.rbox(ps, Vector3(0, 0, -0.05), Vector3(1.1, 0.8, 1.2), red if key == "mg" else Color("3FA35A"), 0.14)
			MK.box(ps, Vector3(0, 0.42, -0.05), Vector3(0.36, 0.06, 0.36), Color.WHITE, Basis(Vector3.UP, PI * 0.25))
			var guns := [-0.25, 0.25] if (level >= 3 or key == "aa") else [0.0]
			for gx in guns:
				MK.cyl(ps, Vector3(gx, 0.0, 0.5), 0.11, 0.11, 0.9, 7, dark, Basis(Vector3.RIGHT, PI * 0.5))
				MK.cyl(ps, Vector3(gx, 0.0, 1.3), 0.15, 0.15, 0.16, 7, steel, Basis(Vector3.RIGHT, PI * 0.5))
				_add_muzzle(Vector3(gx, 0.0, 1.5))
			if key == "aa":
				pitch.rotation.x = -0.5
		"watch":
			pitch.position = Vector3(0, 1.0, 0.2)
			# Wachstube mit Dach
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					MK.rbox(hs, Vector3(1.1 * sx, 1.0, 1.1 * sz), Vector3(0.2, 2.0, 0.2), D.C_WOOD_D, 0.05)
			MK.rbox(hs, Vector3(0, 0.3, 0), Vector3(2.6, 0.6, 2.6), D.C_WOOD, 0.08)
			MK.cyl(hs, Vector3(0, 2.0, 0), 2.1, 0.2, 1.1, 4, red, Basis(Vector3.UP, PI * 0.25))
			MK.rbox(ps, Vector3(0, 0, 0.5), Vector3(0.14, 0.16, 1.8), dark, 0.04)
			MK.cyl(ps, Vector3(0, 0.16, 0.2), 0.08, 0.08, 0.5, 6, steel, Basis(Vector3.RIGHT, PI * 0.5))
			_add_muzzle(Vector3(0, 0, 1.5))
		"cannon":
			pitch.position = Vector3(0, 0.95, 0.0)
			MK.cyl(hs, Vector3.ZERO, 1.3, 1.1, 0.5, 12, dark)
			MK.rbox(ps, Vector3(0, 0, -0.2), Vector3(1.9, 1.2, 1.9), red, 0.2)
			MK.box(ps, Vector3(0, 0.62, -0.2), Vector3(0.6, 0.06, 0.6), Color.WHITE, Basis(Vector3.UP, PI * 0.25))
			MK.cyl(ps, Vector3(0, 0.05, 0.6), 0.34, 0.3, 1.5, 10, dark, Basis(Vector3.RIGHT, PI * 0.5))
			MK.cyl(ps, Vector3(0, 0.05, 2.0), 0.4, 0.4, 0.3, 10, steel, Basis(Vector3.RIGHT, PI * 0.5))
			_add_muzzle(Vector3(0, 0.05, 2.35))
		"flame":
			pitch.position = Vector3(0, 0.7, 0.1)
			MK.cyl(hs, Vector3(0, 0, -0.5), 0.5, 0.5, 1.0, 10, Color("E0A82E"))
			MK.cyl(hs, Vector3(0, 1.0, -0.5), 0.3, 0.3, 0.14, 8, dark)
			MK.cyl(hs, Vector3.ZERO, 0.45, 0.4, 0.4, 8, dark)
			MK.rbox(ps, Vector3(0, 0, 0.1), Vector3(0.7, 0.6, 0.9), red, 0.12)
			MK.cyl(ps, Vector3(0, 0, 0.5), 0.14, 0.12, 0.8, 7, dark, Basis(Vector3.RIGHT, PI * 0.5))
			MK.cyl(ps, Vector3(0, 0, 1.25), 0.2, 0.26, 0.24, 7, steel, Basis(Vector3.RIGHT, PI * 0.5))
			_add_muzzle(Vector3(0, 0, 1.5))
		"mortar":
			pitch.position = Vector3(0, 0.6, 0)
			pitch.rotation.x = -1.0
			MK.cyl(hs, Vector3.ZERO, 1.5, 1.5, 0.3, 12, dark)
			MK.cyl(ps, Vector3(0, 0, -0.5), 0.6, 0.5, 2.0, 10, red, Basis(Vector3.RIGHT, PI * 0.5))
			MK.cyl(ps, Vector3(0, 0, 1.4), 0.62, 0.62, 0.24, 10, steel, Basis(Vector3.RIGHT, PI * 0.5))
			_add_muzzle(Vector3(0, 0, 1.7))
			for i in 3:
				MK.ball(hs, Vector3(1.5, 0.5, -0.6 + i * 0.6), Vector3(0.3, 0.3, 0.3), dark, i, 0.0, 4, 7)
		"tesla", "mini":
			var th := 3.0 if key == "tesla" else 1.4
			pitch.position = Vector3(0, th + 0.4, 0)
			MK.cyl(hs, Vector3.ZERO, 0.5 if key == "tesla" else 0.25, 0.3 if key == "tesla" else 0.15, th, 8, blue)
			for i in (5 if key == "tesla" else 3):
				var rr := (0.8 - i * 0.1) * (1.0 if key == "tesla" else 0.5)
				MK.cyl(hs, Vector3(0, 0.5 + i * th * 0.17, 0), rr, rr, 0.14, 10, Color("E0A82E"))
			_add_muzzle(Vector3.ZERO)
			var orb := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.5 if key == "tesla" else 0.28
			sm.height = sm.radius * 2.0
			sm.radial_segments = 10
			sm.rings = 5
			orb.mesh = sm
			orb.material_override = MK.glow(Color(0.55, 0.9, 1.0))
			orb.position = Vector3(0, th + 0.4, 0)
			orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			head.add_child(orb)
			_spin = orb
		"rocket":
			pitch.position = Vector3(0, 1.2, 0.0)
			pitch.rotation.x = -0.35
			MK.cyl(hs, Vector3.ZERO, 0.5, 0.6, 1.0, 8, dark)
			MK.rbox(ps, Vector3(0, 0, 0), Vector3(2.2, 1.3, 2.0), red, 0.16)
			for gx in [-0.6, 0.0, 0.6]:
				for gy in [-0.3, 0.3]:
					MK.cyl(ps, Vector3(gx, gy, 0.96), 0.22, 0.22, 0.1, 8, Color("14161C"), Basis(Vector3.RIGHT, PI * 0.5))
					MK.cone(ps, Vector3(gx, gy, 0.9), 0.16, 0.3, 6, Color.WHITE, Basis(Vector3.RIGHT, PI * 0.5))
			_add_muzzle(Vector3(-0.6, 0.3, 1.2))
			_add_muzzle(Vector3(0.6, 0.3, 1.2))
			_add_muzzle(Vector3(0, -0.3, 1.2))
		"ice":
			pitch.position = Vector3(0, 0.95, 0.0)
			MK.cyl(hs, Vector3.ZERO, 1.3, 1.1, 0.5, 12, dark)
			MK.rbox(ps, Vector3(0, 0, -0.2), Vector3(1.8, 1.2, 1.8), Color("5DB2EA"), 0.2)
			MK.cyl(ps, Vector3(0, 0.05, 0.6), 0.3, 0.42, 1.6, 8, Color("DDF2FF"), Basis(Vector3.RIGHT, PI * 0.5))
			for i in 3:
				MK.cone(ps, Vector3(-0.5 + i * 0.5, 0.6, -0.2), 0.2, 0.6, 5, Color("DDF2FF"))
			_add_muzzle(Vector3(0, 0.05, 2.3))
	MK.inst(hs, head)
	MK.inst(ps, pitch)
	_pitch_z = pitch.position.z
	if def.mode == "cone":
		_flame = G.fx.make_flame(muzzles[0], def.range)
		_flame.amount = 40
		_flame.spread = 18.0


## Messinghülsen, die beim Schießen seitlich ausgeworfen werden.
func _make_shells(at: Node3D) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.07, 0.07, 0.16)
	p.mesh = bm
	p.material_override = MK.glow(Color(0.95, 0.72, 0.25))
	p.amount = 8
	p.lifetime = 0.55
	p.local_coords = false
	p.emitting = false
	p.direction = Vector3(-1.0 if at.position.x < 0.0 else 1.0, 0.9, 0.0)
	p.spread = 22.0
	p.initial_velocity_min = 2.4
	p.initial_velocity_max = 3.6
	p.gravity = Vector3(0, -14, 0)
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	at.add_child(p)
	return p


func _process(dt: float) -> void:
	if _anims.is_empty() or not is_visible_in_tree():
		return
	Anim.tick(_anims, Time.get_ticks_msec() * 0.001, dt)


func _add_muzzle(p: Vector3) -> void:
	var m := Node3D.new()
	m.position = p
	pitch.add_child(m)
	muzzles.append(m)


# ---------------------------------------------------------------- Logik
func _physics_process(dt: float) -> void:
	if life > 0.0:
		life -= dt
		if life <= 0.0:
			G.fx.puff(global_position + Vector3(0, 1, 0), Color(0.8, 0.8, 0.8), 12)
			G.game.towers.erase(self)
			queue_free()
			return
	if _shell != null:
		_shell_t -= dt
		_shell.emitting = _shell_t > 0.0
	if G.game == null or not active or not G.game.is_running():
		if _flame:
			_flame.emitting = false
		return
	if stun_t > 0.0:                     # lahmgelegt (Geisterqualle) oder vereist (Eisgeist)
		_stunned(dt)
		return
	var horde = G.horde
	var me := pos2()
	var rng: float = def.range * G.game.tower_range_k()        # V6 Paket B: Forschung und Wetter (Nebel)
	if _buff_t > 0.0:
		_buff_t -= dt
	var rate := _buff_k if _buff_t > 0.0 else 1.0
	rate *= G.game.tower_rate(me)
	_think -= dt
	if _think <= 0.0 or (_target != null and _target.st == 2):
		_think = 0.22 + _rng.randf() * 0.06
		match def.target:
			"strongest":
				_target = horde.strongest(me, rng, _air)
			"densest":
				_target = horde.densest(me, rng, def.get("min_range", 0.0), def.get("splash", 3.0), _air)
			_:
				_target = horde.nearest(me, rng, 0.0, false, _air)
		if aim != "":
			var at = _aim_target(horde, me, rng)
			if at != null:
				_target = at
	_cool -= dt * rate
	_recoil = maxf(0.0, _recoil - dt * 8.0)
	pitch.position.z = _pitch_z - _recoil * 0.25
	if _spin:
		_spin.scale = Vector3.ONE * (1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.01) + _recoil * 0.5)
	var firing := false
	if _target == null and def.mode != "chain":
		head.rotation.y += sin(Time.get_ticks_msec() * 0.0006 + _idle_ph) * dt * 0.5
	if _target != null and _target.st != 2:
		var to: Vector2 = _target.p - me
		var want := atan2(to.x, to.y) - global_rotation.y
		var diff := angle_difference(head.rotation.y, want)
		var step := TAU * dt
		head.rotation.y += clampf(diff, -step, step)
		if absf(diff) < 0.12 or def.mode == "chain":
			firing = true
			if def.mode == "cone":
				_tick -= dt
				if _tick <= 0.0:
					_tick = 0.1
					Sfx.loop_at("tower_flame", "flame_loop", global_position, -13.0, 0.85, 0.3)
					var dir := to.normalized()
					var dmg: float = def.damage * dmg_mult * def.rpm / 60.0 * 0.1 * rate
					horde.dmg_src = self
					for e in horde.cone(me, dir, rng, def.cone * 0.5):
						if not e.fly:
							e.burn = maxf(e.burn, def.burn)
							horde.damage(e, dmg, dir, false, false, def.get("element", ""))
					horde.dmg_src = null
			elif _cool <= 0.0:
				_cool = 60.0 / def.rpm
				_fire(_target, to)
	if _flame:
		_flame.emitting = firing


## Paket F: eingestelltes Ziel (nächster, stärkster, fliegend, Boss). null = keins in Reichweite, dann gilt die Standardwahl.
func _aim_target(horde, me: Vector2, rng: float):
	match aim:
		"near":
			return horde.nearest(me, rng, float(def.get("min_range", 0.0)), false, _air)
		"strong":
			return horde.strongest(me, rng, _air)
		"fly":
			if _air != 1:
				return horde.nearest(me, rng, float(def.get("min_range", 0.0)), false, 2)
		"boss":
			var b = horde.boss
			if b != null and b.st < 2 and not b.under and not (_air == 1 and b.fly) and not (_air == 2 and not b.fly) and b.p.distance_to(me) < rng + b.r:
				return b
	return null


func _fire(e, to: Vector2) -> void:
	var horde = G.horde
	var m: Node3D = muzzles[_mi % muzzles.size()]
	_mi += 1
	shots += 1
	_shell_t = 0.16
	var mp: Vector3 = m.global_position
	var dir := to.normalized()
	_recoil = 1.0
	var dmg: float = def.damage * dmg_mult
	Sfx.play_at(def.sound, mp, -13.0 if def.mode == "hitscan" else -8.0, 1.0, 0.07)
	var ty: float = 0.5 * e.sc + (2.4 if e.fly else 0.0)
	var tp := Vector3(e.p.x, ty, e.p.y)
	horde.dmg_src = self
	var me_ref: WeakRef = weakref(self)
	match def.mode:
		"hitscan":
			G.fx.flash(mp, tp - mp, 1.3)
			G.fx.tracer(mp, tp, Color(1, 0.9, 0.5), 0.07)
			horde.damage(e, dmg, dir, false, false, def.get("element", ""))
		"pierce":
			G.fx.flash(mp, tp - mp, 2.0, true)
			var hits: Array = horde.ray(pos2(), dir, def.range, 1 + int(def.pierce), 0.35)
			var found := false
			for h in hits:
				if h[1] == e:
					found = true
			if not found:
				horde.damage(e, dmg, dir, true, false, def.get("element", ""))
			var end := tp
			for h in hits:
				var he = h[1]
				end = Vector3(he.p.x, 0.6, he.p.y)
				horde.damage(he, dmg, dir, true, false, def.get("element", ""))
			G.fx.tracer(mp, end, Color(1, 1, 0.85), 0.12, 0.12)
		"cannon":
			G.fx.flash(mp, tp - mp, 2.6, true)
			var tg := Vector3(e.p.x, 0.1, e.p.y)
			var spl: float = def.splash
			G.game.launch(mp, tg, clampf(mp.distance_to(tg) / 30.0, 0.2, 0.6), 1.2, Color(0.15, 0.15, 0.18), func(): _blast_by(me_ref, tg, spl, dmg, {}, Color(1.0, 0.55, 0.15)))
		"mortar":
			G.fx.flash(mp, Vector3(dir.x, 2.0, dir.y), 2.4, true)
			var tg2 := Vector3(e.p.x + e.v.x * 0.8, 0.1, e.p.y + e.v.y * 0.8)
			var spl2: float = def.splash
			G.game.launch(mp, tg2, 1.2, 11.0, Color(0.15, 0.15, 0.18), func(): _blast_by(me_ref, tg2, spl2, dmg, {}, Color(1.0, 0.55, 0.15)))
		"rocket":
			G.fx.flash(mp, tp - mp, 2.2, true)
			var tg3 := Vector3(e.p.x, 0.4, e.p.y)
			var spl3: float = def.splash
			G.game.launch(mp, tg3, clampf(mp.distance_to(tg3) / 24.0, 0.25, 1.3), 2.0, Color(0.95, 0.95, 0.9), func(): _blast_by(me_ref, tg3, spl3, dmg, {}, Color(1.0, 0.55, 0.15)), true)
		"ice":
			var tg4 := Vector3(e.p.x, 0.1, e.p.y)
			var spl4: float = def.splash
			var stun: float = def.stun
			G.game.launch(mp, tg4, 0.5, 2.0, Color(0.7, 0.92, 1.0), func(): _blast_by(me_ref, tg4, spl4, dmg, {"stun": stun, "knock": 0.0, "element": "eis"}, Color(0.6, 0.88, 1.0)))
		"chain":
			var prev := mp
			var cur = e
			var done: Array = []
			for i in int(def.chain):
				if cur == null:
					break
				done.append(cur)
				var cp := Vector3(cur.p.x, 0.5 * cur.sc + (2.4 if cur.fly else 0.0), cur.p.y)
				G.fx.lightning(prev, cp)
				cur.slow = maxf(cur.slow, def.slow)
				horde.damage(cur, dmg, Vector2.ZERO, false, false, def.get("element", ""))
				prev = cp
				var nxt = null
				var bd := 20.0
				for o in horde.in_radius(cur.p, 4.5):
					if not done.has(o):
						var dd: float = o.p.distance_squared_to(cur.p)
						if dd < bd:
							bd = dd
							nxt = o
				cur = nxt
	horde.dmg_src = null


## V6 Paket B: Einschlag eines Geschosses – der Schaden zählt für den Turm, der es abgefeuert hat (falls es ihn noch gibt).
static func _blast_by(ref: WeakRef, pos: Vector3, radius: float, dmg: float, opts: Dictionary, col: Color) -> void:
	if G.game == null:
		return
	var src = ref.get_ref()
	if G.horde != null:
		G.horde.dmg_src = src
	G.game.blast(pos, radius, dmg, opts, col)
	if G.horde != null:
		G.horde.dmg_src = null


# ---------------------------------------------------------------- lahmlegen (Paket 11)
var stun_t := 0.0                # so lange schießt der Turm nicht
var _stun_kind := ""
var _stun_fx := 0.0


## Legt den Turm für t Sekunden lahm. kind: "zap" (Funken) oder "ice" (vereist).
func stun(t: float, kind := "zap") -> void:
	if life > 0.0 and settler:
		return
	stun_t = maxf(stun_t, t)
	_stun_kind = kind
	_target = null
	if G.fx:
		G.fx.ring(global_position, 2.2, Color(0.7, 0.9, 1.0) if kind == "ice" else Color(1.0, 0.95, 0.4), 0.4)
	Sfx.play_at("tower_frozen" if kind == "ice" else "tower_stunned", global_position, -7.0, 1.0, 0.3)


func _stunned(dt: float) -> void:
	stun_t -= dt
	if _flame:
		_flame.emitting = false
	_stun_fx -= dt
	if _stun_fx <= 0.0 and G.fx:
		_stun_fx = 0.35
		G.fx.puff(global_position + Vector3(0, 2.2, 0), Color(0.75, 0.92, 1.0) if _stun_kind == "ice" else Color(1.0, 0.95, 0.5), 4, 0.7)
	if head != null and _stun_kind != "ice":
		head.rotation.y += sin(Time.get_ticks_msec() * 0.03) * dt * 2.0      # zuckt hilflos

