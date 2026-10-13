extends Node3D
## Ein Gebäude der Hauptbasis (oder eines Außenpostens): Modell, Leben, Lebensbalken,
## Turm (falls Verteidigung), Baustellen-Anzeige und Produktions-Blase.

const D = preload("res://src/data.gd")
const MK = preload("res://src/mk.gd")
const Models = preload("res://src/models.gd")
const Tower = preload("res://src/tower.gd")
const Anim = preload("res://src/anim.gd")
const Bubble = preload("res://src/bubble.gd")
const UI = preload("res://src/ui.gd")

var b: Dictionary = {}          # Eintrag aus dem Spielstand (leer bei Außenposten)
var key := ""
var def: Dictionary
var alive := true
var hp := 100.0
var max_hp := 100.0
var mid := Vector2.ZERO
var radius := 2.0
var cost := 30.0
var blocks_player := true
var tower: Node3D
var model: Node3D
var size := Vector2i(2, 2)
var constructing := false
var sig := ""
var shielded := false
var _bar: Node3D
var _rubble: Node3D               # Trümmer (Blender-Modell je Größe oder Ersatz aus dem Code)
var _taken := 0.0
var _window := 0.0
var bubble: Node3D              # Sammelblase (Produktion)
var gift: Node3D                # zweite Blase für Abholungen (tägliches Geschenk, Lieferung)
var gate := false               # Tor: sperrt Gegner, öffnet für Freunde
var open_k := 0.0               # 0 = zu, 1 = offen
var passable := false           # offenes Tor mit einem Freund im Durchgang: auch Gegner kommen hindurch
var obstacle := false
var stopped := false            # Produktion steht (Speicher voll)
var level := 1
var _open_t := 0.0
var _door_l: Node3D
var _door_r: Node3D
var _lamp_o: Node3D
var _lamp_c: Node3D
var _site: Node3D
var _timer: Label3D
var _tbar: Node3D
var _timer_t := 0.0
var _sign: Label3D
var _anims: Array = []
var _pop := 0.0
var _bar_t := 0.0
var dmg_stage := 0              # 0 heil, 1 unter 60 % Leben (dmg1_*), 2 unter 30 % (dmg2_*, Rauch, flackerndes Licht)
var fill_stage := -1            # sichtbarer Füllstand (fillN_*), -1 = noch nicht gesetzt
var _states := {}               # Zustands-Objekte des Modells (Models.states)
var _emitters: Array = []       # Rauch/Dampf/Funken des Modells (laufen nur bei Arbeit)
var _dmg_smoke: CPUParticles3D
var _flicker: Array = []
var _flick_t := 0.0
var _blink: Node3D              # Blinklicht der Mine
var _site_anims: Array = []     # Planen des Gerüsts
var _clip: Array = []           # Rohbau-Materialien beim ersten Bau (Models.clip_begin)
var _model_h := 3.0
var _slot: Node3D               # Garage: veh_slot, Statue: statue_slot
var _slot_node: Node3D
var _slot_key := "?"


func setup(entry: Dictionary, building_key: String, level: int, footprint: Vector2i, center: Vector2, rot: int, under_construction: bool) -> void:
	b = entry
	key = building_key
	def = D.BUILDINGS[key]
	size = footprint
	mid = center
	position = Vector3(center.x, 0, center.y)
	radius = maxf(footprint.x, footprint.y) * D.CELL * 0.5
	constructing = under_construction
	self.level = level
	obstacle = def.cat == "obstacle"
	gate = key == "tor"
	max_hp = float(def.hp) * pow(1.18, level - 1)
	if key == "bunker":
		max_hp = D.bunker_hp(level) * (1.0 + preload("res://src/research.gd").bonus("bunker_hp"))     # V6 Paket B: Bunkerpanzer
	if gate:
		# Tore sind 2,2-mal so stark wie die Mauer derselben Bauart; im Bau nur ein Viertel
		max_hp = float(def.hp) * float(D.WALL_TIERS[clampi(level - 1, 0, 2)].hp) * (1.0 + P.cmd_bonus("wall_hp")) * (1.0 + P.outpost_bonus("wall_hp"))
		blocks_player = false
	if obstacle:
		blocks_player = false
	hp = max_hp * (0.25 if gate and under_construction else 1.0)
	cost = 24.0 + max_hp * 0.02
	if def.has("tower"):
		tower = Tower.new()
		add_child(tower)
		tower.setup(def.tower, level)
		tower.dmg_mult = pow(D.TOWER_DMG_GROWTH, level - 1) * (1.0 + P.cmd_bonus("tower_dmg"))
		tower.active = not under_construction
		tower.aim = String(entry.get("aim", ""))           # Paket F: Turmziel je Turm
		model = tower
	else:
		model = Models.building(key, level, P.wall_tier_built())
		add_child(model)
		_anims = Anim.collect(model)
	if gate:
		_door_l = Models.find(model, "door_l")
		_door_r = Models.find(model, "door_r")
		_lamp_o = Models.find(model, "lamp_open_glow")
		_lamp_c = Models.find(model, "lamp_closed_glow")
		if _lamp_o:
			_lamp_o.visible = false
		set_process(true)
	# frisch gesetzte Gebäude ploppen auf
	if G.game != null and G.game.time > 1.0:
		_pop = 1.0
		model.scale = Vector3(0.6, 0.6, 0.6)
	model.rotation.y = -rot * PI * 0.5
	_states = Models.states(model)
	if tower == null:
		_emitters = model.find_children("*", "CPUParticles3D", true, false)
		_setup_slot()
	if key == "mine":
		_blink = Models.find(model, "lamp_glow")
		if _blink != null:
			set_process(true)
	if Models.state_max(_states, "fill") > 0:
		_update_fill()
		P.resources_changed.connect(_update_fill)
	_refresh_work()
	if under_construction:
		_make_site()
		if not b.is_empty():
			begin_reveal()
			_update_timer()


func _make_site() -> void:
	_wake()
	_site = Node3D.new()
	add_child(_site)
	var fp: Array = def.size
	var sname := Models.scaffold_name(int(fp[0]), int(fp[1]))
	if sname != "":
		# Gerüst aus Blender, passend zur Grundfläche; steht wie das Gebäude
		var sc := Models.glb(sname)
		sc.name = "scaffold"
		sc.rotation.y = model.rotation.y + (0.0 if sname == "b_scaffold_%dx%d" % [int(fp[0]), int(fp[1])] else PI * 0.5)
		_site.add_child(sc)
		var native := Models.height(sc)
		if native > 0.5:
			sc.scale.y = clampf((Models.height(model) + 0.3) / native, 1.0, 1.45)
		_site_anims = Anim.collect(sc, false)
	elif size == Vector2i(1, 1) and Models.has_glb("wall_site"):
		var ws := MeshInstance3D.new()
		ws.name = "scaffold"
		ws.mesh = Models.wall_site()
		ws.material_override = MK.mat_lin()
		_site.add_child(ws)
	else:
		_make_site_frame()
	# Baudrohne
	var ds := MK.begin()
	MK.rbox(ds, Vector3.ZERO, Vector3(0.6, 0.3, 0.6), Color("EDEDF2"), 0.1)
	MK.box(ds, Vector3(0, 0.2, 0), Vector3(1.3, 0.04, 0.12), Color("3A4152"))
	MK.box(ds, Vector3(0, 0.2, 0), Vector3(0.12, 0.04, 1.3), Color("3A4152"))
	var dr: Node3D = MK.inst(ds, _site, Vector3(0, 4.4, 0))
	if Models.has_glb("p_drone"):
		dr.queue_free()
		dr = Models.glb("p_drone")
		_site.add_child(dr)
	dr.name = "drone"
	MK.glow_box(dr, Vector3(0, -0.2, 0), Vector3(0.16, 0.1, 0.16), Color("38A9F5"))
	# Restzeit und Fortschritt über der Baustelle
	_timer = Label3D.new()
	_timer.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_timer.no_depth_test = true
	_timer.render_priority = 8
	_timer.outline_render_priority = 7
	_timer.font = UI.font(true)
	_timer.font_size = 64
	_timer.outline_size = 20
	_timer.pixel_size = 0.0085
	_timer.outline_modulate = Color("06142E")
	_timer.position = Vector3(0, _top_y() + 1.5, 0)
	_site.add_child(_timer)
	_tbar = MK.make_bar(clampf(radius * 1.1, 1.8, 4.0), Color("FFD23E"), 0.26)
	_site.add_child(_tbar)
	_update_timer()


## Ersatz-Gerüst aus dem Code (nur wenn das Blender-Modell b_scaffold_<w>x<h> fehlt).
func _make_site_frame() -> void:
	var st := MK.begin()
	var w := size.x * D.CELL * 0.5
	var h := size.y * D.CELL * 0.5
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			MK.rbox(st, Vector3(w * sx, 1.6, h * sz), Vector3(0.22, 3.2, 0.22), Color("E0A82E"), 0.05)
	for sz in [-1.0, 1.0]:
		MK.box(st, Vector3(0, 2.6, h * sz), Vector3(w * 2.0, 0.14, 0.14), Color("E0A82E"))
		MK.box(st, Vector3(0, 1.3, h * sz), Vector3(w * 2.0, 0.14, 0.14), Color("23262E"))
	MK.inst(st, _site)


## Höhe, in der Blasen und Anzeigen über dem Gebäude schweben.
func _top_y() -> float:
	var e := Models.find(model, "bubble") if model != null else null
	if e != null:
		return e.position.y
	return 5.2 if radius > 2.5 else (4.2 if radius > 1.5 else 3.2)


func _update_timer() -> void:
	if _timer == null or b.is_empty():
		return
	var left := float(b.get("done_at", 0.0)) - P.now()
	_timer.text = UI.time_text(maxf(left, 0.0))
	var t0 := float(b.get("t0", 0.0))
	var total := float(b.get("done_at", 0.0)) - t0
	var k := clampf(1.0 - left / total, 0.0, 1.0) if total > 0.0 and t0 > 0.0 else 0.0
	MK.set_bar(_tbar, k)
	_update_clip(k)


## Erster Bau: das Gebäude wächst mit dem Baufortschritt von unten nach oben (Rohbau-Materialien, siehe Models.clip_begin).
## Gebäude aus dem Spielstand treibt _update_timer() an; wer ohne Spielstand-Eintrag baut (Außenposten), ruft
## begin_reveal() und danach regelmäßig set_progress(k) selbst auf.
func begin_reveal() -> void:
	if _clip.is_empty():
		_clip = Models.clip_begin(model)
		_model_h = maxf(Models.height(model), 1.0)
	_update_clip(0.0)


func set_progress(k: float) -> void:
	if _tbar != null:
		MK.set_bar(_tbar, clampf(k, 0.0, 1.0))
	_update_clip(clampf(k, 0.0, 1.0))


func _update_clip(k: float) -> void:
	if not _clip.is_empty():
		Models.clip_set(_clip, global_position.y + _model_h * (0.12 + 0.88 * k) * model.scale.y)


## Sammelblase zeigen oder verbergen. icon = "" verbirgt. st: 0 normal, 1 fast voll, 2 voll.
func set_bubble(icon: String, text := "", st := 0) -> void:
	if icon == "":
		if bubble:
			bubble.hide_now()
		_set_stopped(false)
		return
	if bubble == null:
		bubble = Bubble.new()
		add_child(bubble)
		bubble.base_y = _top_y()
		bubble.position = Vector3(0, bubble.base_y, 0)
		bubble.tag = self
	bubble.show_as(icon, text, st)
	_set_stopped(st == 2)


## Zweite Blase für Dinge zum Abholen (liegt etwas seitlich, damit beide Platz haben).
func set_gift(icon: String, text := "", id := 0) -> void:
	if icon == "":
		if gift:
			gift.hide_now()
		return
	if gift == null:
		gift = Bubble.new()
		add_child(gift)
		gift.base_y = _top_y() + 0.4
		gift.position = Vector3(-2.2, gift.base_y, 0)
	gift.tag = id
	gift.show_as(icon, text, 1)


## Steht die Produktion, weil der Speicher voll ist, ruht alles: keine Bewegung, kein Rauch, Schild "Voll".
func _set_stopped(on: bool) -> void:
	if on == stopped:
		return
	stopped = on
	_refresh_work()
	if on and _sign == null:
		_sign = Label3D.new()
		_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_sign.no_depth_test = true
		_sign.render_priority = 9
		_sign.outline_render_priority = 8
		_sign.font = UI.font(true)
		_sign.font_size = 56
		_sign.outline_size = 18
		_sign.pixel_size = 0.008
		_sign.text = "VOLL"
		_sign.modulate = Color("FF4D62")
		_sign.outline_modulate = Color.WHITE
		_sign.position = Vector3(0, 1.6, radius * 0.9)
		add_child(_sign)
	if _sign:
		_sign.visible = on


## Schornstein-Rauch, Dampf und Funken laufen nur, wenn das Gebäude arbeitet (nicht im Rohbau, nicht bei vollem Speicher, nicht zerstört).
func _refresh_work() -> void:
	var on := alive and not stopped and not constructing
	for p in _emitters:
		if is_instance_valid(p) and p != _dmg_smoke:
			p.emitting = on


## Schadensstufe nach hp / max_hp: unter 60 % dmg1_* (Risse, Ruß), unter 30 % dmg2_* mit Rauch und flackerndem Licht.
func _update_damage() -> void:
	var stage := 0
	if alive and not constructing and max_hp > 0.0:
		var k := hp / max_hp
		stage = 2 if k < 0.3 else (1 if k < 0.6 else 0)
	if stage == dmg_stage:
		return
	dmg_stage = stage
	Models.set_state(_states, "dmg", stage)
	if stage == 2 and _dmg_smoke == null and G.fx != null:
		var at := Models.find(model, "fx_smoke_dmg")
		if at == null:
			# Modelle ohne eigenen Rauchpunkt: Rauch steigt aus der Mitte auf
			at = Node3D.new()
			at.name = "fx_smoke_dmg"
			at.position = Vector3(0, maxf(_top_y() - 1.6, 1.2), 0)
			add_child(at)
		_dmg_smoke = G.fx.make_emitter(at, "smoke")
		_dmg_smoke.amount = 14
		_dmg_smoke.scale_amount_min = 1.0
		_dmg_smoke.scale_amount_max = 1.9
		_dmg_smoke.color = Color(0.36, 0.34, 0.34)
	if _dmg_smoke != null:
		_dmg_smoke.emitting = stage == 2
	for n in _flicker:
		if is_instance_valid(n):
			n.visible = true
	_flicker.clear()
	if stage == 2:
		for n in model.find_children("*_glow*", "MeshInstance3D", true, false):
			var nm := String(n.name)
			if n.visible and not (nm.begins_with("lamp_open") or nm.begins_with("lamp_closed") or nm.begins_with("pulse_")):
				_flicker.append(n)
		_wake()


## Füllstand-Objekte fillN_*: Lager nach dem Anteil gefüllter Lagerkapazität über alle Rohstoffe,
## Sägewerk (und andere Produktion) nach dem Bestand des eigenen Rohstoffs.
func _update_fill() -> void:
	var top := Models.state_max(_states, "fill")
	if top <= 0:
		return
	var ratio := 0.0
	if def.has("prod"):
		var r := String(def.prod)
		ratio = clampf(float(P.res(r)) / maxf(1.0, float(P.cap(r))), 0.0, 1.0)
	else:
		for r in D.CAP_BASE:
			ratio += clampf(float(P.res(r)) / maxf(1.0, float(P.cap(r))), 0.0, 1.0)
		ratio /= maxf(1.0, float(D.CAP_BASE.size()))
	var lv := clampi(int(ceil(ratio * top - 0.001)), 0, top)
	if lv != fill_stage:
		fill_stage = lv
		Models.set_state(_states, "fill", lv)


## Garage: das gewählte Fahrzeug steht im Leerobjekt veh_slot. Statue: die Figur des gewählten Helden
## steht versteinert auf statue_slot (sonst bleibt die neutrale Figur statue_default sichtbar).
func _setup_slot() -> void:
	if key == "garage":
		_slot = Models.find(model, "veh_slot")
	elif key == "statue":
		_slot = Models.find(model, "statue_slot")
	if _slot == null or constructing:
		return
	_refresh_slot()
	P.changed.connect(_refresh_slot)


func _refresh_slot() -> void:
	var want: String = P.vehicle_sel() if key == "garage" else String(P.d.hero_sel)
	if want == _slot_key:
		return
	_slot_key = want
	if _slot_node != null:
		_slot_node.queue_free()
		_slot_node = null
	if key == "garage":
		if want != "":
			_slot_node = Models.vehicle(want)
	else:
		_slot_node = Models.statue_figure(want)
		var dflt := Models.find(model, "statue_default")
		if dflt != null:
			dflt.visible = _slot_node == null
	if _slot_node != null:
		_slot.add_child(_slot_node)


func _wake() -> void:
	set_process(true)


func _process(dt: float) -> void:
	if _anims.is_empty() and _pop <= 0.0 and _site == null and not (_bar and _bar.visible) and _window <= 0.0 and not gate and _blink == null and dmg_stage < 2:
		set_process(false)
		return
	if gate:
		_tick_gate(dt)
	var tt := Time.get_ticks_msec() * 0.001
	if _pop > 0.0:
		_pop = maxf(0.0, _pop - dt * 2.6)
		var k := 1.0 - _pop
		# federnd: schießt über das Ziel hinaus und pendelt ein
		var sx := 1.0 + sin(k * PI * 2.5) * 0.18 * _pop - 0.4 * _pop * _pop
		var sy := 1.0 - sin(k * PI * 2.5) * 0.22 * _pop - 0.4 * _pop * _pop
		model.scale = Vector3(sx, sy, sx)
	if not _anims.is_empty() and alive and model.visible and not stopped and not constructing:
		Anim.tick(_anims, tt, dt)
	if _blink != null:
		_blink.visible = fmod(tt + mid.x * 0.37, 1.4) < 0.22
	if dmg_stage >= 2 and not _flicker.is_empty():
		_flick_t -= dt
		if _flick_t <= 0.0:
			_flick_t = randf_range(0.05, 0.28)
			var lit := randf() < 0.6
			for n in _flicker:
				if is_instance_valid(n):
					n.visible = lit
	if _site:
		if not _site_anims.is_empty():
			Anim.tick(_site_anims, tt, dt)
		_timer_t -= dt
		if _timer_t <= 0.0:
			_timer_t = 0.25
			_update_timer()
		if _tbar:
			_tbar.global_transform = Transform3D(G.cam.cam_basis(), global_position + Vector3(0, _top_y() + 0.75, 0))
		var dr: Node3D = _site.get_node("drone")
		var t := Time.get_ticks_msec() * 0.001
		dr.position = Vector3(cos(t * 1.3) * radius * 0.5, 4.4 + sin(t * 2.1) * 0.3, sin(t * 1.3) * radius * 0.5)
		var rotor := Models.find(dr, "spin_rotor")
		if rotor != null:
			rotor.rotate_object_local(Vector3.UP, dt * 30.0)
			dr.rotation.y = -t * 1.3
		else:
			dr.rotation.y = t * 6.0
	if _bar and _bar.visible:
		_bar_t -= dt
		_bar.global_transform = Transform3D(G.cam.cam_basis(), global_position + Vector3(0, 5.0 if radius > 2.5 else 4.0, 0))
		if _bar_t <= 0.0 and hp >= max_hp:
			_bar.visible = false
	if _window > 0.0:
		_window -= dt
		if _window <= 0.0:
			_taken = 0.0


func hurt(d: float, force := false) -> void:
	if not alive or G.game.barrier_t > 0.0 or G.ch("god_base"):
		return
	d *= G.game.dmg_factor(self)
	if shielded:
		d *= 0.5
	# die vorderste Reihe kann nicht beliebig viel Schaden pro Sekunde anrichten
	if not force:
		var cap := maxf(max_hp * 0.2, 60.0)
		if _taken >= cap:
			return
		d = minf(d, cap - _taken)
		_taken += d
		if _window <= 0.0:
			_window = 1.0
			_wake()
	hp -= d
	Sfx.play_at("struct_hit", global_position, -13.0, 1.0 if radius < 2.5 else 0.8, 0.14)
	_show_bar()
	if hp <= 0.0:
		_destroy()
	else:
		_update_damage()


func _show_bar() -> void:
	if _bar == null:
		_bar = MK.make_bar(clampf(radius * 1.2, 1.6, 4.5), D.C_BAR_BLUE if key == "bunker" else D.C_BAR_RED, 0.3)
		add_child(_bar)
	_bar.visible = true
	_bar_t = 4.0
	_wake()
	MK.set_bar(_bar, hp / max_hp)


func repair(ratio: float) -> void:
	if not alive:
		return
	hp = minf(max_hp, hp + max_hp * ratio)
	if ratio > 0.0:
		Sfx.play_at("repair", global_position, -8.0, 1.0, 0.3)
	_show_bar()
	_update_damage()


func _destroy() -> void:
	alive = false
	hp = 0.0
	model.visible = false
	if tower:
		tower.active = false
	if _bar:
		_bar.visible = false
	if bubble:
		bubble.hide_now()
	if gift:
		gift.hide_now()
	passable = false
	_update_damage()
	_refresh_work()
	var rk := "b_rubble_%d" % clampi(maxi(size.x, size.y), 1, 4)
	if _rubble == null and Models.has_glb(rk) and not gate:
		# Paket G2: Trümmer-Modell je Größe (blender/def_g2.py)
		var rb := Models.glb(rk)
		rb.rotation.y = float(int(mid.x * 3.0 + mid.y * 5.0) % 4) * PI * 0.5
		if size.x != size.y:
			rb.scale = Vector3(float(size.x) / maxf(size.x, size.y), 1.0, float(size.y) / maxf(size.x, size.y)) if int(rb.rotation.y / (PI * 0.5)) % 2 == 0 else Vector3(float(size.y) / maxf(size.x, size.y), 1.0, float(size.x) / maxf(size.x, size.y))
		add_child(rb)
		_rubble = rb
	if _rubble == null:
		var st := MK.begin()
		var rng := RandomNumberGenerator.new()
		rng.seed = int(mid.x * 31 + mid.y * 17)
		for i in 7:
			MK.rbox(st, Vector3(rng.randf_range(-1, 1) * radius * 0.7, 0.25, rng.randf_range(-1, 1) * radius * 0.7),
				Vector3(rng.randf_range(0.5, 1.2), 0.5, rng.randf_range(0.5, 1.2)), MK.vary(Color("6A6E80"), 0.15, rng), 0.08, Basis(Vector3.UP, rng.randf() * TAU))
		_rubble = MK.inst(st, self)
	_rubble.visible = true
	G.field.dirty = true
	G.fx.explosion(global_position + Vector3(0, 1.5, 0), radius + 1.0, Color(0.8, 0.7, 0.5))
	Sfx.play_at("struct_destroy", global_position, -2.0)
	G.game.on_structure_destroyed(self)


## Stellt das Gebäude nach einem Kampf wieder her.
func restore() -> void:
	alive = true
	hp = max_hp * (0.25 if gate and constructing else 1.0)
	model.visible = true
	if tower:
		tower.active = not constructing
	if _rubble:
		_rubble.visible = false
	if _bar:
		_bar.visible = false
	_update_damage()
	_refresh_work()


## Kurzes Aufploppen (nach Ausbau, Reparatur, Einsammeln).
func pop() -> void:
	_pop = 0.6
	_wake()


# ---------------------------------------------------------------- Tor
## Öffnet für Held, Fahrzeug und Bewohner (näher als 3,5 m), schließt 1 s nach dem Letzten.
## Kommt ein Gegner näher als 6 m, schließt es sofort – außer ein Freund steht im Durchgang.
func _tick_gate(dt: float) -> void:
	var g = G.game
	if g == null or not alive:
		passable = false
		return
	var want := false
	var inside := false
	for p: Vector2 in g.friends():
		var dd := p.distance_to(mid)
		if dd < 3.5:
			want = true
			if dd < 1.7:
				inside = true
	var enemy := false
	if g.mode != "peace" and g.horde != null and g.horde.alive > 0:
		enemy = g.horde.nearest(mid, 6.0) != null
	if enemy and not inside:
		want = false
		_open_t = 0.0
	if want:
		_open_t = 1.0
	else:
		_open_t = maxf(0.0, _open_t - dt)
	var target := 1.0 if _open_t > 0.0 else 0.0
	var before := open_k
	open_k = move_toward(open_k, target, dt / 0.35)
	if before == 0.0 and open_k > 0.0:
		Sfx.play_at("gate_open", global_position, -8.0, 1.0, 0.1)
	elif before == 1.0 and open_k < 1.0:
		Sfx.play_at("gate_close", global_position, -9.0, 1.0, 0.1)
	passable = open_k > 0.5 and inside
	if open_k != before:
		var k := open_k * open_k * (3.0 - 2.0 * open_k)
		if _door_l:
			_door_l.rotation.y = -1.75 * k
		if _door_r:
			_door_r.rotation.y = 1.75 * k
		if _lamp_o:
			_lamp_o.visible = open_k > 0.5
		if _lamp_c:
			_lamp_c.visible = open_k <= 0.5


## Weltposition (x, z) eines Leerobjekts im Modell (door, work_1, work_2, drop …); fehlt es, die Mitte.
func spot(node_name: String) -> Vector2:
	var n := Models.find(model, node_name) if model != null else null
	if n == null:
		return mid
	var g := n.global_position if n.is_inside_tree() else global_transform * (model.transform * n.position)
	return Vector2(g.x, g.z)
