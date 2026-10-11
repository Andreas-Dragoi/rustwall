extends Node3D
## Der aktive Begleiter in der Welt (Hauptbasis und Expedition; Paket B).
##  - folgt dem Helden auf dessen Spur (Brotkrumen): wo der Held gehen kann, kann auch der Begleiter gehen –
##    nie durch Mauern oder Gebäude (field.blocks_player), Tore benutzt er wie der Held. Hängt er fest oder
##    ist er zu weit weg, springt er zum Helden (mit Staubwolke). Flieger fliegen frei darüber.
##  - trägt in der Expedition den Rucksack-Inhalt sichtbar (Teil-Modelle je Rohstoff, companion_data.gd)
##  - Besonderheiten: Münzen sammeln, selbst abbauen, kämpfen, heilen, leuchten, Truhen zeigen, Held antreiben
##  - kann Schaden nehmen und umfallen; steht nach DOWN_TIME wieder auf (geht nie verloren)
##  - steigt mit Einsatz auf (Erfahrung für eingesammelte Ladung, Münzen und Treffer)
## Animationen sind bewegte Teile wie bei wildlife.gd: Stehen, Laufen, Freude/Aufnehmen, Besonderheit, Umfallen.

const D = preload("res://src/data.gd")
const CD = preload("res://src/companion_data.gd")
const Models = preload("res://src/models.gd")

const LEG_PHASE := {"leg_fl": 1.0, "leg_br": 1.0, "leg_mr": 1.0, "leg_fr": -1.0, "leg_bl": -1.0, "leg_ml": -1.0, "leg_l": 1.0, "leg_r": -1.0}

var w: Node3D                      # Welt (base_world.gd oder expedition.gd)
var key := ""
var def: Dictionary
var model: Node3D
var body: Node3D
var head: Node3D
var tail: Node3D
var sled: Node3D
var cargo: Node3D                  # Ladefläche (Leerobjekt aus Blender)
var load_root: Node3D              # die Ladungsteile
var legs: Array = []               # [Node3D, Phase]
var arms: Array = []
var wings: Array = []
var rotors: Array = []
var fly := false
var move := "quad"
var pos := Vector2.ZERO
var yaw := 0.0
var speed_now := 0.0
var st := "follow"                 # follow | mine | down | sad
var hp := 100.0
var max_hp := 100.0
var down_t := 0.0
var trail: Array = []              # Brotkrumen des Helden (Vector2)
var cargo_pieces := 0
var teleports := 0                 # (Test) so oft zum Helden gesprungen
var blocked_frames := 0            # (Test) Bilder, in denen der Begleiter auf einem gesperrten Feld stand
var last_us := 0.0                 # Rechenzeit des letzten Bildes (Mikrosekunden)
var mined := 0.0                   # (Test) selbst abgebaut
var coins_got := 0.0               # (Test) eingesammelte Münzen

var _t := 0.0
var _walk_ph := 0.0
var _joy := 0.0
var _special := 0.0
var _special_kind := ""
var _idle_t := 8.0
var _los := false
var _los_t := 0.0
var _stuck := 0.0
var _ab_t := 0.0
var _hurt_t := 0.0
var _fight_t := 0.0
var _mine_t := 0.0
var _mine_node = null
var _cargo_t := 0.0
var _cargo_sig := "-"
var _last_weight := -1.0
var _check_t := 0.0
var _body_y := 0.0
var _body_rot := Vector3.ZERO
var _light: OmniLight3D
var _speed_set := -1.0             # Tempo, das zuletzt beim Helden gesetzt wurde (Antreiber)
var _speed_orig := 0.0
var _markers := {}                 # Truhe -> Label3D
var _snd_t := 0.0
var _area_key := ""
var _scale := 1.0


func setup(world: Node3D) -> void:
	w = world
	name = "Companion"
	if w.get("adef") is Dictionary:
		_area_key = String(w.adef.get("key", ""))
	if G.arg("comp") != "":                 # Bilder und Tests: --comp=<schlüssel> oder --comp=none
		var ck := G.arg("comp")
		if ck != "none":
			CD.give(ck, "admin")
		CD.set_active("" if ck == "none" else ck)
	_build(CD.active())
	if w.hero != null:
		_place_behind(true)
	# erster Besuch der Basis mit Begleiter: kurzer Hinweis
	if key != "" and w.mode == "peace" and not bool(CD.state().get("hello", false)) and G.autotest == "" and not G.selftest and G.shots_dir == "":
		CD.state()["hello"] = true
		P.toast.emit.call_deferred("%s begleitet dich und trägt auf Expeditionen deine Beute. Mehr Begleiter: Menü „Begleiter“." % String(def.name))
	if G.arg("camdist") != "" and w.cam != null:   # Bilder: Kamera näher heran
		w.cam.set_deferred("dist", float(G.arg("camdist")))
	if G.arg("herowish") != "" and w.hero != null:  # Bilder: Held läuft in diese Bildschirm-Richtung (x:y), Begleiter folgt
		var hw := G.arg("herowish").split(":")
		get_tree().create_timer(0.3).timeout.connect(func():
			if w.hero != null and w.cam != null:
				w.hero.test_wish = w.cam.screen_to_world_dir(Vector2(float(hw[0]), float(hw[1]))))
	if G.arg("compshow") != "":                    # Bilder: Held und Begleiter von der Seite, Rucksack gefüllt
		get_tree().create_timer(0.8).timeout.connect(_showcase)
	if G.arg("compline") != "":                    # Bilder: alle Begleiter nebeneinander, beladen
		_lineup.call_deferred()


## Baut die Figur für den Begleiter k ("" = keiner).
func _build(k: String) -> void:
	_restore_hero_speed()
	if model != null:
		model.queue_free()
		model = null
	if _light != null:
		_light.queue_free()
		_light = null
	for m in _markers.values():
		if is_instance_valid(m):
			m.queue_free()
	_markers.clear()
	key = k
	legs.clear()
	arms.clear()
	wings.clear()
	rotors.clear()
	body = null
	head = null
	tail = null
	sled = null
	cargo = null
	load_root = null
	_cargo_sig = "-"
	cargo_pieces = 0
	visible = key != ""
	if key == "" or not Models.has_glb("comp_" + key):
		visible = false
		key = "" if not Models.has_glb("comp_" + key) else key
		return
	def = CD.def(key)
	move = String(def.get("move", "quad"))
	fly = move == "fly"
	model = Models.glb("comp_" + key)
	add_child(model)
	_scale = float(def.get("scale", CD.MODEL_SCALE))
	model.scale = Vector3.ONE * _scale
	body = Models.find(model, "body")
	head = Models.find(model, "head")
	tail = Models.find(model, "tail")
	sled = Models.find(model, "sled")
	cargo = Models.find(model, "cargo")
	for nm in LEG_PHASE:
		var l := Models.find(model, nm)
		if l != null:
			legs.append([l, float(LEG_PHASE[nm])])
	for nm in ["arm_l", "arm_r"]:
		var a := Models.find(model, nm)
		if a != null:
			arms.append([a, -1.0 if nm == "arm_l" else 1.0])
	for nm in ["wing_l", "wing_r"]:
		var wg := Models.find(model, nm)
		if wg != null:
			wings.append([wg, -1.0 if nm == "wing_l" else 1.0])
	for n in model.find_children("spin_*", "Node3D", true, false):
		rotors.append(n)
	if body != null:
		_body_y = body.position.y
		_body_rot = body.rotation
	if cargo != null:
		load_root = Node3D.new()
		load_root.name = "Load"
		cargo.add_child(load_root)
	# Schatten nur vom Rumpf (spart Zeichenaufrufe im Schattendurchgang)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if mi != body and mi != sled:
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	max_hp = CD.max_hp(key)
	if w.get("dp_mult") != null:
		max_hp *= float(w.dp_mult)
	hp = max_hp
	st = "follow"
	if CD.abil_of(key, "glow") > 0.0:
		_light = OmniLight3D.new()
		_light.light_color = Color("E8FF9A")
		_light.omni_range = CD.abil("glow")
		_light.light_energy = 0.6
		_light.shadow_enabled = false
		_light.position = Vector3(0, 1.3, 0)
		add_child(_light)
	_last_weight = -1.0


func _place_behind(force: bool) -> void:
	var hp2: Vector2 = w.hero.pos2()
	var back := -Vector2(sin(w.hero.rotation.y), cos(w.hero.rotation.y))
	var best := hp2
	for i in 12:
		var a := (i % 2 * 2 - 1) * (i / 2) * 0.5
		var q: Vector2 = hp2 + back.rotated(a) * (1.8 + 0.15 * i)
		if fly or not _blocked(q):
			best = q
			break
	if force or best != hp2:
		pos = best
		trail.clear()
		position = Vector3(pos.x, 0, pos.y)
		yaw = w.hero.rotation.y


func _blocked(p: Vector2) -> bool:
	return w.field != null and w.field.blocks_player(p)


## Freie Sicht (für Laufen) vom Punkt a nach b: alle 0,5 m ein Feld prüfen.
func _clear(a: Vector2, b: Vector2) -> bool:
	var d := a.distance_to(b)
	var n := int(ceil(d / 0.5))
	for i in range(1, n + 1):
		if _blocked(a.lerp(b, float(i) / float(n))):
			return false
	return true


## Hier landen Abbau-Brocken (fliegen zur Ladefläche).
func load_point() -> Vector3:
	if cargo != null and is_inside_tree():
		return cargo.global_position + Vector3(0, 0.25, 0)
	return global_position + Vector3(0, 1.0, 0)


func is_down() -> bool:
	return st == "down"


# ================================================================= Schleife
func _physics_process(dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	_t += dt
	_check_t -= dt
	if _check_t <= 0.0:
		_check_t = 0.5
		if CD.active() != key:
			_build(CD.active())
			if w.hero != null:
				_place_behind(true)
			if w.get("cap") != null and w.mode == "exp":
				w.cap = P.backpack_cap(w.hero.key, P.vehicle_sel()) + CD.active_carry(_area_key)
	if key == "" or model == null or w.hero == null:
		return
	var hero = w.hero
	var hp2: Vector2 = hero.pos2()
	if not hero.alive:
		st = "sad" if st != "down" else st
	elif st == "sad":
		st = "follow"
	match st:
		"down":
			down_t -= dt
			speed_now = 0.0
			if down_t <= 0.0:
				st = "follow"
				hp = max_hp * 0.6
				_joy = 0.6
				Sfx.play_at("comp_getup", global_position, -8.0, 1.0, 0.1)
		"sad":
			speed_now = 0.0
		"mine":
			_tick_mine(dt, hp2)
		_:
			_tick_follow(dt, hp2)
	if st != "down":
		_tick_abilities(dt, hp2)
	_tick_hurt(dt)
	_tick_cargo(dt)
	position = Vector3(pos.x, 0, pos.y)
	rotation.y = yaw
	_animate(dt)
	if not fly and st != "down" and _blocked(pos):
		blocked_frames += 1
	last_us = float(Time.get_ticks_usec() - t0)
	if G.arg("compdebug") != "" and Engine.get_physics_frames() % 30 == 0:
		print("COMP %s st=%s pos=%s hero=%s d=%.1f trail=%d tp=%d vis=%s down=%.1f" % [key, st, str(pos.round()), str(hp2.round()), pos.distance_to(hp2), trail.size(), teleports, str(visible), down_t])


# ================================================================= Folgen
func _tick_follow(dt: float, hp2: Vector2) -> void:
	var hero = w.hero
	if trail.is_empty() or (trail[-1] as Vector2).distance_to(hp2) > 0.7:
		trail.append(hp2)
		if trail.size() > 120:
			trail.remove_at(0)
	var dist := pos.distance_to(hp2)
	var tele := CD.TELEPORT_DIST if not hero.mounted else CD.TELEPORT_DIST * 1.5
	if dist > tele or trail.size() >= 120 or _stuck > 1.4 or (not fly and _blocked(pos)):
		_blink()
		return
	_los_t -= dt
	if _los_t <= 0.0:
		_los_t = 0.25
		_los = fly or (dist < 16.0 and _clear(pos, hp2))
		if _los:
			trail = [hp2]
	while trail.size() > 1 and pos.distance_to(trail[0]) < 0.6:
		trail.remove_at(0)
	var want := CD.FOLLOW_DIST + (0.6 if sled != null else 0.0)
	if dist <= want:
		speed_now = move_toward(speed_now, 0.0, dt * 12.0)
		yaw = lerp_angle(yaw, atan2(hp2.x - pos.x, hp2.y - pos.y), minf(1.0, dt * 3.0))
		_stuck = 0.0
		return
	var tgt: Vector2 = hp2 if _los or trail.is_empty() else trail[0]
	var to := tgt - pos
	var tl := to.length()
	if tl < 0.05:
		if not trail.is_empty():
			trail.remove_at(0)
		return
	var sp: float = float(def.speed) * clampf((dist - want) / 1.5, 0.35, 1.0)
	if dist > want + 1.0:
		sp = maxf(sp, hero.speed_now * 1.05)          # langsame Begleiter bleiben trotzdem dran
	if dist > 6.0:
		sp = maxf(sp, maxf(hero.speed_now * 1.25, float(def.speed) * 1.5))
	if hero.mounted:
		sp = maxf(sp, hero.speed_now * 1.1)
	speed_now = move_toward(speed_now, sp, dt * 20.0)
	var step := minf(speed_now * dt, tl)
	var np := pos + to / tl * step
	if not fly and _blocked(np):
		# an der Kante entlang rutschen
		var side := Vector2(-to.y, to.x) / tl
		var a := pos + side * step
		var b := pos - side * step
		if not _blocked(a):
			np = a
		elif not _blocked(b):
			np = b
		else:
			np = pos
		_stuck += dt
	else:
		_stuck = maxf(0.0, _stuck - dt)
	pos = np
	yaw = lerp_angle(yaw, atan2(to.x, to.y), minf(1.0, dt * 9.0))


## Zum Helden springen (hängt fest oder zu weit weg).
func _blink() -> void:
	var old := global_position
	_place_behind(true)
	_stuck = 0.0
	teleports += 1
	if w.fx != null:
		w.fx.puff(old + Vector3(0, 0.5, 0), Color(0.9, 0.85, 0.7), 8, 0.8)
		w.fx.puff(Vector3(pos.x, 0.5, pos.y), Color(0.9, 0.85, 0.7), 10, 0.9)
	Sfx.play_at("comp_blink", Vector3(pos.x, 0.5, pos.y), -10.0, 1.0, 0.1)


# ================================================================= Besonderheiten
func _tick_abilities(dt: float, hp2: Vector2) -> void:
	var hero = w.hero
	# Antreiber: Tempo des Helden (refresh_stats setzt es neu – dann wieder aufschlagen)
	var run := CD.abil("run")
	if run > 0.0 and hero.alive:
		if absf(hero.base_speed - _speed_set) > 0.001:
			_speed_orig = hero.base_speed
			_speed_set = _speed_orig * (1.0 + run)
			hero.base_speed = _speed_set
	if _light != null:
		var night: bool = w.is_night() or w.daytime == "abend" or int(w.get("dusk") if w.get("dusk") != null else 0) > 0
		_light.light_energy = lerpf(_light.light_energy, 2.2 if night else 0.5, minf(1.0, dt * 2.0))
	_ab_t -= dt
	if _ab_t > 0.0:
		return
	_ab_t = 0.25
	var p3 := Vector3(pos.x, 0.6, pos.y)
	# Münzen
	var cr := CD.abil("coins")
	if cr > 0.0 and G.coins != null and w.coins != null:
		var v: float = w.coins.take(pos, cr)
		if v > 0.0:
			w.collect_coin(v)
			coins_got += v
			CD.add_xp(v * CD.XP_PER_COIN)
			_joy = maxf(_joy, 0.35)
			Sfx.play_at("coin", p3, -12.0, 1.25, 0.1)
	# Heilen
	var hl := CD.abil("heal")
	if hl > 0.0 and hero.alive and hero.hp < hero.max_hp and float(hero._since_hit) > 3.0:
		hero.heal(hero.max_hp * hl * 0.25)
		if int(_t * 4.0) % 8 == 0 and w.fx != null:
			w.fx.ring(hero.global_position, 1.2, Color(0.7, 1.0, 0.5, 0.6), 0.4)
	# Kämpfen
	var fd := CD.abil("fight")
	_fight_t -= 0.25
	if fd > 0.0 and _fight_t <= 0.0 and w.horde != null and w.is_running():
		var e = w.horde.nearest(pos, 4.5)
		if e != null:
			_fight_t = 1.1
			yaw = atan2(e.p.x - pos.x, e.p.y - pos.y)
			var k: float = float(w.get("hp_mult")) if w.get("hp_mult") != null else 1.0
			var killed: bool = w.horde.damage(e, fd * k, pos)
			_special = 0.5
			_special_kind = "fight"
			if w.fx != null:
				w.fx.puff(Vector3(e.p.x, 0.6, e.p.y), Color(0.8, 0.75, 0.7), 6, 1.2)
			Sfx.play_at("comp_punch", p3, -8.0, 1.0, 0.15)
			if killed:
				CD.add_xp(CD.XP_PER_KILL)
	# Selbst abbauen
	if CD.abil("mine") > 0.0 and w.mode == "exp" and st == "follow" and hero.alive:
		_mine_node = _pick_node(hp2)
		if _mine_node != null:
			st = "mine"
			_mine_t = 0.6
	# Truhen zeigen
	if CD.abil_of(key, "chests") > 0.0 and w.get("pois") != null:
		_tick_markers()
	# Erfahrung für eingesammelte Ladung
	if w.mode == "exp":
		var wt: float = float(w.weight)
		if _last_weight >= 0.0 and wt > _last_weight:
			_level_check(CD.add_xp((wt - _last_weight) * CD.XP_PER_WEIGHT))
		_last_weight = wt
	# ab und zu die Besonderheit zeigen und rufen
	_idle_t -= 0.25
	if _idle_t <= 0.0 and speed_now < 0.3 and st == "follow":
		_idle_t = randf_range(9.0, 16.0)
		_special = 1.2
		_special_kind = "show"
		_call()


func _level_check(lv: int) -> void:
	if lv <= 0:
		return
	_joy = 1.4
	if w.mode == "exp":
		w.cap = P.backpack_cap(w.hero.key, P.vehicle_sel()) + CD.active_carry(_area_key)
	max_hp = CD.max_hp(key) * (float(w.dp_mult) if w.get("dp_mult") != null else 1.0)
	P.toast.emit("%s ist jetzt Stufe %d! Tragkraft +%d %%" % [String(def.name), lv, int(round(CD.CARRY_PER_LEVEL * 100.0))])
	Sfx.play("comp_levelup", -4.0)
	if w.fx != null:
		w.fx.confetti(global_position + Vector3(0, 0.8, 0), 2)


func _call() -> void:
	if _snd_t > _t:
		return
	_snd_t = _t + 2.0
	Sfx.play_at("comp_%s" % key, global_position + Vector3(0, 0.6, 0), -9.0, 1.0, 0.08)


## Quelle in der Nähe, an der der Begleiter selbst arbeiten kann.
func _pick_node(hp2: Vector2):
	if w.get("nodes") == null:
		return null
	var best = null
	var bd := 1.0e9
	for n in w.nodes:
		if n.gone or n.res == "coins" or w.room_for(n.res) < 1.0:
			continue
		var dh: float = n.p.distance_to(hp2)
		if dh > 8.0:
			continue
		var d: float = n.p.distance_to(pos)
		if d < bd and d < 10.0:
			bd = d
			best = n
	return best


func _tick_mine(dt: float, hp2: Vector2) -> void:
	var n = _mine_node
	if n == null or n.gone or hp2.distance_to(pos) > 10.0 or w.room_for(n.res) < 1.0 or not w.hero.alive:
		st = "follow"
		_mine_node = null
		return
	var stand: Vector2 = n.p + (pos - n.p).normalized() * maxf(1.0, n.reach() * 0.7)
	var to := stand - pos
	if to.length() > 0.3:
		speed_now = move_toward(speed_now, float(def.speed) * 0.8, dt * 20.0)
		var np := pos + to.normalized() * minf(speed_now * dt, to.length())
		if not fly and _blocked(np):
			st = "follow"
			_mine_node = null
			return
		pos = np
		yaw = lerp_angle(yaw, atan2(to.x, to.y), minf(1.0, dt * 9.0))
		return
	speed_now = 0.0
	yaw = lerp_angle(yaw, atan2(n.p.x - pos.x, n.p.y - pos.y), minf(1.0, dt * 9.0))
	_mine_t -= dt
	_special = maxf(_special, 0.3)
	_special_kind = "mine"
	if _mine_t <= 0.0:
		_mine_t = CD.abil("mine")
		var amt: float = n.hit() * 0.6
		if amt > 0.0:
			mined += amt
			w._spawn_chunks(n, amt)
			Sfx.play_at("comp_mine", Vector3(n.p.x, 0.5, n.p.y), -9.0, 1.1, 0.15)
			if w.fx != null:
				w.fx.puff(Vector3(n.p.x, 0.7, n.p.y), D.RES_COLOR.get(n.res, Color.WHITE).lightened(0.2), 4, 0.8)


func _tick_markers() -> void:
	for poi in w.pois:
		if poi.kind != "chest":
			continue
		var m: Label3D = _markers.get(poi)
		var show: bool = not poi.done and poi.p.distance_to(pos) < 40.0
		if show and m == null:
			m = Label3D.new()
			m.text = "Truhe!"
			m.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			m.font_size = 56
			m.outline_size = 14
			m.pixel_size = 0.014
			m.modulate = Color("FFD23E")
			m.no_depth_test = true
			w.add_child(m)
			m.position = Vector3(poi.p.x, 2.6, poi.p.y)
			_markers[poi] = m
			Sfx.play_at("comp_found_chest", Vector3(poi.p.x, 1.0, poi.p.y), -6.0)
			_special = 1.0
			_special_kind = "show"
		if m != null:
			m.visible = show
			m.position.y = 2.6 + sin(_t * 3.0) * 0.2


# ================================================================= Schaden
func _tick_hurt(dt: float) -> void:
	_hurt_t -= dt
	if _hurt_t > 0.0:
		return
	_hurt_t = 0.3
	if st == "down" or w.horde == null or not w.is_running():
		if st != "down" and hp < max_hp:
			hp = minf(max_hp, hp + max_hp * 0.02)
		return
	var dmg := 0.0
	for e in w.horde.in_radius(pos, 0.9):
		if e.stat:
			continue
		var ed: Dictionary = D.ENEMIES[e.t]
		dmg += float(ed.dmg) / maxf(float(ed.get("interval", 1.0)), 0.2) * 0.3 * float(e.dp)
	if fly:
		dmg *= 0.5
	if dmg <= 0.0:
		return
	hurt(dmg)


func hurt(dmg: float) -> void:
	if st == "down" or key == "":
		return
	hp -= dmg
	if hp <= 0.0:
		hp = 0.0
		st = "down"
		down_t = CD.DOWN_TIME
		_mine_node = null
		Sfx.play_at("comp_down", global_position, -6.0, 1.0, 0.1)
		if w.fx != null:
			w.fx.float_text(global_position + Vector3(0, 1.6, 0), "Autsch!", Color("FF8A8A"))
			w.fx.puff(global_position + Vector3(0, 0.4, 0), Color(0.9, 0.9, 0.9), 10, 1.0)


# ================================================================= Ladung
func _tick_cargo(dt: float) -> void:
	_cargo_t -= dt
	if _cargo_t > 0.0 or load_root == null:
		return
	_cargo_t = 0.2
	var counts := {}
	if w.mode == "exp" and w.get("loot") != null:
		counts = CD.cargo_counts(w.loot, w.weight, w.cap, CD.slot_count(def.slots), w.unit_weight)
	var sig := str(counts)
	if sig == _cargo_sig:
		return
	_cargo_sig = sig
	var before := cargo_pieces
	cargo_pieces = CD.build_cargo(load_root, counts, def.slots)
	if cargo_pieces > before:
		_joy = maxf(_joy, 0.45)
		if _snd_t <= _t:
			_snd_t = _t + 0.6
			Sfx.play_at("comp_pickup", global_position + Vector3(0, 0.8, 0), -10.0, 1.0, 0.15)


## Ladungsteile je Rohstoff (für Tests und Anzeige).
func cargo_kinds() -> Dictionary:
	var out := {}
	if load_root == null:
		return out
	for c in load_root.get_children():
		var nm := String(c.name)
		out[nm] = int(out.get(nm, 0)) + 1
	return out


# ================================================================= Animation
func _animate(dt: float) -> void:
	var mk := clampf(speed_now / maxf(float(def.speed), 0.1), 0.0, 1.6)
	_walk_ph += dt * (4.0 + speed_now * 2.2) * (1.0 if mk > 0.05 else 0.0)
	_joy = maxf(0.0, _joy - dt)
	_special = maxf(0.0, _special - dt)
	var sw := sin(_walk_ph) * mk
	# Umfallen / Aufstehen
	var down_k := 1.0 if st == "down" else 0.0
	if body != null:
		var bob := absf(sin(_walk_ph)) * 0.035 * mk + sin(_t * 2.1) * 0.012
		if fly:
			bob = sin(_t * 2.4) * 0.07 - down_k * (_body_y - 0.35)
		var tilt_z := lerpf(body.rotation.z, 1.4 * down_k, minf(1.0, dt * 6.0))
		var pitch := sin(_walk_ph * 2.0) * 0.04 * mk
		if _special > 0.0 and _special_kind == "mine":
			pitch = 0.25 + sin(_t * 18.0) * 0.12
		if st == "sad":
			pitch = 0.15
		body.position.y = _body_y + bob
		body.rotation = Vector3(_body_rot.x + pitch, _body_rot.y, tilt_z)
		if move == "slither":
			var sq := 1.0 + sin(_walk_ph * 0.8) * 0.07 * mk
			body.scale = Vector3(1.0 / sqrt(sq), 1.0, sq)
	# Freude: Hüpfer
	var hop := 0.0
	if _joy > 0.0 and st != "down":
		hop = absf(sin(_joy * PI * 3.0)) * 0.22 * minf(_joy * 2.0, 1.0)
	var lunge := 0.0
	if _special > 0.0 and _special_kind == "fight":
		lunge = sin(_special / 0.5 * PI) * 0.35
	if model != null:
		model.position = Vector3(0, hop, lunge) * _scale
		var pulse := 1.0
		if _special > 0.0 and _special_kind == "show" and CD.abil_of(key, "heal") > 0.0:
			pulse = 1.0 + sin(_special * 12.0) * 0.06
		model.scale = Vector3.ONE * pulse * _scale
	for l in legs:
		var n: Node3D = l[0]
		n.rotation.x = sw * 0.55 * float(l[1]) * (1.0 - down_k)
		if move == "hex":
			n.rotation.z = absf(sin(_walk_ph + float(l[1]))) * 0.15 * mk
	for a in arms:
		var n2: Node3D = a[0]
		var swing := -sw * 0.5 * float(a[1])
		if _special > 0.0 and _special_kind == "fight" and float(a[1]) > 0.0:
			swing = -sin(_special / 0.5 * PI) * 1.6
		if _joy > 0.0:
			swing = -1.2 * minf(_joy * 2.0, 1.0)
		n2.rotation.x = swing
	for wg in wings:
		var n3: Node3D = wg[0]
		var spd := 30.0 if key == "gluehwurm" else 11.0
		var amp := 0.25 if key == "gluehwurm" else (0.55 if mk > 0.1 or _joy > 0.0 else 0.35)
		if st == "down":
			amp = 0.05
		n3.rotation.z = sin(_t * spd) * amp * float(wg[1])
	for r in rotors:
		(r as Node3D).rotate_y(dt * (38.0 if st != "down" else 4.0))
	if tail != null:
		var wag := sin(_t * (13.0 if _joy > 0.0 else 3.0)) * (0.5 if _joy > 0.0 else 0.18)
		if key == "biber":
			tail.rotation.x = wag * 0.6
		else:
			tail.rotation.y = wag
	if head != null:
		var hy := 0.0
		var hx := sin(_walk_ph * 2.0) * 0.05 * mk
		if mk < 0.1:
			hy = sin(_t * 0.6) * 0.35
		if _special > 0.0 and _special_kind == "show":
			hy = sin(_special * 5.2) * 0.8
			hx = -0.2
		if _special > 0.0 and _special_kind == "mine":
			hx = 0.35 + sin(_t * 18.0) * 0.2
		if _joy > 0.0:
			hx = -0.3
		if st == "sad":
			hx = 0.4
		head.rotation = Vector3(lerpf(head.rotation.x, hx, minf(1.0, dt * 10.0)), lerpf(head.rotation.y, hy, minf(1.0, dt * 6.0)), 0.0)


func _restore_hero_speed() -> void:
	if _speed_set > 0.0 and w != null and w.hero != null and is_instance_valid(w.hero) and absf(w.hero.base_speed - _speed_set) < 0.001:
		w.hero.base_speed = _speed_orig
	_speed_set = -1.0


func _exit_tree() -> void:
	for m in _markers.values():
		if is_instance_valid(m):
			m.queue_free()
	_markers.clear()


## Nur für Bilder (--compline=1): alle zwölf Begleiter in einer Reihe neben dem Helden, jeder mit Ladung.
func _lineup() -> void:
	var hp2: Vector2 = w.hero.pos2()
	var mix := {"wood": 2, "stone": 1, "metal": 1, "fuel": 1, "cells": 1, "parts": 1, "shards": 1}
	var i := 0
	for k in CD.ORDER:
		var m := Models.glb("comp_" + String(k))
		w.add_child(m)
		m.scale = Vector3.ONE * CD.MODEL_SCALE
		var col := i % 6
		var row := int(i / 6)
		m.position = Vector3(hp2.x - 7.5 + col * 3.0, 0, hp2.y + 3.0 + row * 4.0)
		m.rotation.y = 0.5
		var cg := Models.find(m, "cargo")
		if cg != null:
			var lr := Node3D.new()
			cg.add_child(lr)
			var dd: Dictionary = CD.def(String(k))
			var n := CD.slot_count(dd.slots)
			var counts := {}
			var j := 0
			for r in mix:
				if j >= n:
					break
				counts[r] = 1
				j += 1
			CD.build_cargo(lr, counts, dd.slots)
		i += 1


## Nur für Bilder (--compshow=1): Held blickt nach links (Kamera-Sicht), Begleiter steht rechts hinter ihm.
func _showcase() -> void:
	if w == null or w.hero == null or w.cam == null:
		return
	var right3: Vector3 = w.cam.cam.global_transform.basis.x
	var right := Vector2(right3.x, right3.z).normalized()
	var h = w.hero
	h.test_wish = Vector2.ZERO
	h.rotation.y = atan2(-right.x, -right.y) + float(G.arg("compyaw", "0"))
	if w.mode == "exp":
		w.loot = {}
		w._recalc_weight()
		for r in ["wood", "stone", "metal", "fuel", "cells", "parts"]:
			w.add_pack(r, w.cap * (0.3 if r == "wood" else 0.1) / w.unit_weight(r))
	pos = h.pos2() + right * (2.4 if not fly else 1.6)
	if not fly and _blocked(pos):
		pos = h.pos2() - right * 2.4
	trail.clear()
	yaw = h.rotation.y
	if G.arg("compwalk") != "":                    # Held läuft nach links aus dem Bild, der Begleiter hinterher
		h.test_wish = -right
