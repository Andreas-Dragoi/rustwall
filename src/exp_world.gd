extends Node3D
## Lebendige Expedition (Paket Welt, V5). Gehört zu expedition.gd, das es beim Bau der Karte anlegt
## (pre_generate / post_generate) und jedes Bild tick() ruft:
##   Tageslauf    Ankunft am Morgen, dann Tag, vor der Dämmerung Abend, in der Dämmerung Nacht (Farben wie in der Basis)
##   Wetter       Regen-, Staub- und Nebelteilchen, Umgebungsklang je Gebiet (Tag/Nacht überblendet)
##   Ereignisse   je Gebiet eines mit Spielwirkung: Regen (Grüntal), Nebel (Forst), Sandsturm (Staubebene), Ebbe/Flut (Küste),
##                Giftnebel (Sumpf), Lawine (Frostpass), Meteoriten (Krater), Vulkanausbruch (Vulkaninsel, Paket Z),
##                Blitzgewitter mit Stromausfall (Stadtruinen, Paket Z2)
##   Wahrzeichen  großes Modell an festem Ort; entdecken gibt Tagebuchseite 0
##   Quellen      gebietseigene Quellen, nur mit dem passenden Werkzeug abbaubar (welt_state.gd)
##   Tagebuch     je Besuch liegt eine fehlende Seite (1 oder 2) irgendwo im Gebiet
##   Karawane     fährt im Mittelring, verkauft Werkzeug, Begleiter-Ei, seltene Ladung, Treibstoff gegen Feldmünzen
##   Nebenquest   Auftraggeber in der Landezone, drei Fundstücke, Belohnung Werkzeug + Seite 3
## Zahlen und Texte: data_welt.gd.

const D = preload("res://src/data.gd")
const DW = preload("res://src/data_welt.gd")
const WS = preload("res://src/welt_state.gd")
const Models = preload("res://src/models.gd")
const MK = preload("res://src/mk.gd")
const ResNode = preload("res://src/resource_node.gd")
const Humanoid = preload("res://src/humanoid.gd")
const Weather = preload("res://src/weather.gd")
const UI = preload("res://src/ui.gd")

var ex: Node3D                    # expedition.gd
var area := 0
var ak := ""
var rng := RandomNumberGenerator.new()
var t := 0.0
var log: Array[String] = []       # (Test) was geschehen ist
# ---- Tageslauf
var daytime := "morgen"
var mood_w := {}
var forced := ""
var night_k := 0.0
var _env_t := 0.0
var _base_fog := 0.0022
# ---- Ereignis
var ev: Dictionary = {}
var ev_left := 0.0
var ev_next := DW.EVENT_FIRST
var ev_count := 0
var ev_phase := 0
var _ev_items: Array = []         # {kind, p, r, t, n (Knoten), ring, v}
var _ev_tick := 0.0
var _ev_spawned := 0
var rain_k := 0.0
var dust_k := 0.0
var fog_k := 0.0
var _rain: CPUParticles3D
var _dust: CPUParticles3D
var _rainbow: MeshInstance3D
var _rainbow_mat: ShaderMaterial
var _rainbow_t := 0.0
var _aggro0 := 13.0
var bonus_nodes: Array = []
# ---- Wahrzeichen
var landmark: Node3D
var lm_p := Vector2.INF
var lm_found := false
var _lm_cells := PackedInt32Array()
# ---- Tagebuchseite
var page_node: Node3D
var page_p := Vector2.INF
var page_id := -1
# ---- Quellen
var sources: Array = []
var _tool_msg_t := 0.0
# ---- Karawane
var caravan: Node3D
var _cart: Node3D
var _wheels: Array = []
var car_path := PackedVector2Array()
var car_i := 0
var car_p := Vector2.INF
var car_stop := 0.0
var car_go := DW.CARAVAN_STOP_EVERY
var car_on := false
var _panel: Control
var _panel_sig := ""
# ---- Nebenquest
var giver: Node3D
var giver_p := Vector2.INF
var _giver_sign: Label3D
var q_items: Array = []           # {n, p, done}
var talk_k := 0.0
var _talk_ready := true          # nach einem Gespräch erst wieder, wenn der Held weggegangen ist
var _q_placed := false


func _rng_seed(extra: String) -> int:
	return hash("rustwall-welt|%s|%s" % [ak, extra])


# ================================================================= Aufbau
## Vor dem Verstreuen der Hindernisse: Platz für das Wahrzeichen sperren (mit Rand, damit keine Bäume hineinragen).
func pre_generate(e: Node3D) -> void:
	ex = e
	area = int(e.area)
	ak = String(e.adef.key)
	name = "Welt"
	var lr := RandomNumberGenerator.new()
	lr.seed = _rng_seed("landmark")
	var lmd: Dictionary = DW.LANDMARKS.get(ak, {})
	if lmd.is_empty():
		return
	var a0 := lr.randf() * TAU
	for k in 60:
		var a := a0 + k * 0.37
		var dist := lr.randf_range(float(lmd.dist[0]), float(lmd.dist[1]))
		var p := Vector2(cos(a), sin(a)) * dist
		var why := ""
		if p.distance_to(e.outpost.C) < 24.0:
			why = "Außenbasis"
		elif e._near_passage(p, 14.0 if k < 30 else 8.0):
			why = "Durchgang"
		elif absf(p.x) > e.HALFM - 14.0 or absf(p.y) > e.HALFM - 14.0:
			why = "Rand"
		if "dbg" in G.arg("welt"):
			print("WELT lm %s versuch %d %s %s" % [ak, k, str(p.round()), why])
		if why != "":
			continue
		lm_p = e.field.center(e.field.idx(p))
		break
	if lm_p != Vector2.INF:
		_lm_cells = e.field.block_circle_tracked(lm_p, float(lmd.r) * DW.LANDMARK_SCALE + 3.0)


## Nach dem Verstreuen: Rand wieder freigeben, Modell setzen.
func post_generate() -> void:
	if lm_p == Vector2.INF:
		return
	var lmd: Dictionary = DW.LANDMARKS[ak]
	ex.field.release_cells(_lm_cells)
	_lm_cells = ex.field.block_circle_tracked(lm_p, float(lmd.r) * DW.LANDMARK_SCALE)
	if Models.has_glb(String(lmd.model)):
		var yaw := atan2(-lm_p.x, -lm_p.y)                  # Vorderseite zeigt zur Landestelle
		landmark = ex.place_model(String(lmd.model), Vector3(lm_p.x, 0, lm_p.y), yaw, DW.LANDMARK_SCALE)
	lm_found = WS.landmark_seen(ak)


## Nach dem Aufbau der Karte (Quellen, Orte): Seite, gebietseigene Quellen, Auftraggeber, Teilchen, Klang.
func setup() -> void:
	rng.seed = _rng_seed("tag%d" % P.day_index())
	if G.arg("seed") != "":
		rng.seed = int(G.arg("seed")) + 77
	_aggro0 = ex.horde.aggro_range
	var dt_arg := G.arg("daytime")
	if dt_arg in Weather.MOODS:
		forced = dt_arg
	elif G.selftest or G.autotest != "":
		forced = "tag"
	_real_field(func():
		_place_sources()
		_place_page())
	_place_giver()
	_make_rain()
	_make_dust()
	_make_rainbow()
	_update_daytime(0.0, true)
	_sounds()


func _exit_tree() -> void:
	MK.mat_glow().set_shader_parameter("boost", 1.6)
	_close_panel()


## Solange die Sperren stehen, gilt außerhalb der Landezone alles als fest (expedition.gd spart so Rechenzeit).
## Zum Verteilen von Quellen, Seiten und Fundstücken kurz das echte Feld einsetzen.
func _real_field(cb: Callable) -> void:
	if ex._outer_solid.is_empty():
		cb.call()
		return
	var keep: PackedByteArray = ex.field.solid
	ex.field.solid = ex._outer_solid
	cb.call()
	ex._outer_solid = ex.field.solid
	ex.field.solid = keep


## Freier, erreichbarer Punkt in einem Abstandsband um c (Ringe der Karte werden beachtet).
func pick_near(c: Vector2, lo: float, hi: float, others: Array = [], min_other := 6.0):
	for tries in 60:
		var a := rng.randf() * TAU
		var p: Vector2 = c + Vector2(cos(a), sin(a)) * rng.randf_range(lo, hi)
		if absf(p.x) > ex.HALFM - 8.0 or absf(p.y) > ex.HALFM - 8.0:
			continue
		if ex.field.is_solid(p) or ex.field.blocks_player(p):
			continue
		if not ex._barriers_open() and p.length() > D.EXP_RING_LAND - 3.0:
			continue
		var ok := true
		for o in others:
			if p.distance_to(o) < min_other:
				ok = false
				break
		if ok and p.distance_to(ex.outpost.C) > 10.0:
			return ex.field.center(ex.field.idx(p))
	return null


func _add_node(kind: String, p: Vector2, ring: int) -> Node3D:
	var nd: Dictionary = DW.SOURCES[kind]
	var amt := rng.randf_range(float(nd.min), float(nd.max))
	if not bool(nd.get("no_factor", false)):
		amt *= float(ex.factor)
	var n := ResNode.new()
	ex.add_child(n)
	n.setup(kind, p, roundf(amt), ring, rng.randf() * TAU)
	n.cells = ex.field.block_circle_tracked(p, 0.9)
	ex.nodes.append(n)
	return n


func _place_sources() -> void:
	var kind := "src_" + ak
	if not DW.SOURCES.has(kind) or ex.mission == "befreiung":
		return
	var taken: Array = [ex.START]
	for i in DW.SOURCES_PER_VISIT:
		var p = ex._pick(D.EXP_RING_LAND + D.EXP_RING_W + 6.0, 12.0, taken, D.EXP_RING_MID + 20.0, rng)
		if p == null:
			continue
		p = ex.field.center(ex.field.idx(p))
		taken.append(p)
		sources.append(_add_node(kind, p, 1 if p.length() < D.EXP_RING_MID else 2))


func _place_page() -> void:
	page_id = WS.next_map_page(ak)
	if page_id < 0 or ex.mission == "befreiung":
		return
	var p = ex._pick(D.EXP_RING_LAND + 14.0, 20.0, [ex.START, lm_p], 999.0, rng)
	if p == null:
		page_id = -1
		return
	page_p = p
	page_node = Models.glb("p_journal") if Models.has_glb("p_journal") else Node3D.new()
	page_node.position = Vector3(p.x, 0, p.y)
	ex.add_child(page_node)


func _place_giver() -> void:
	var q: Dictionary = DW.QUESTS.get(ak, {})
	if q.is_empty() or ex.mission == "befreiung" or WS.quest(ak).state >= 2:
		return
	var gr := RandomNumberGenerator.new()
	gr.seed = _rng_seed("giver")
	var p = null
	for tries in 40:
		var a := gr.randf() * TAU
		var c: Vector2 = Vector2(cos(a), sin(a)) * gr.randf_range(10.0, 18.0)
		if not ex.field.blocks_player(c) and c.distance_to(ex.outpost.C) > 13.0 and not ex.field.blocks_player(c + Vector2(1, 0)):
			p = ex.field.center(ex.field.idx(c))
			break
	if p == null:
		return
	giver_p = p
	giver = Humanoid.new()
	ex.add_child(giver)
	giver.build({"helm": Color(q.suit).darkened(0.3), "suit": Color(q.suit), "kind": "settler", "tier": 0})
	giver.scale = Vector3.ONE * D.CHAR_SCALE * 0.95
	giver.position = Vector3(p.x, 0, p.y)
	giver.rotation.y = atan2(-p.x, -p.y)
	_giver_sign = Label3D.new()
	_giver_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_giver_sign.no_depth_test = true
	_giver_sign.fixed_size = true
	_giver_sign.pixel_size = 0.0012
	_giver_sign.font_size = 34
	_giver_sign.outline_size = 12
	_giver_sign.modulate = D.C_GOLD
	_giver_sign.position = Vector3(0, 2.25, 0)
	giver.add_child(_giver_sign)
	_update_giver_sign()
	if WS.quest(ak).state == 1:
		_place_items()


# ================================================================= Bild für Bild
func tick(dt: float, pp: Vector2) -> void:
	if t < 0.6 and t + dt >= 0.6 and G.arg("welt") != "":
		_shot_setup(G.arg("welt"))
	if t > 0.6 and lm_p != Vector2.INF and G.shots_dir != "" and "lm" in G.arg("welt").split(","):
		ex.cam.override_target = Vector3(lm_p.x, 2.0, lm_p.y)          # Bilder: Kamera bleibt auf dem Wahrzeichen
	t += dt
	_env_t -= dt
	if _env_t <= 0.0:
		_env_t = 0.25
		_update_daytime(0.25)
		_sounds()
	_tick_event(dt, pp)
	_tick_particles(dt)
	_tick_landmark(pp)
	_tick_page(dt, pp)
	_tick_caravan(dt, pp)
	_tick_quest(dt, pp)
	_tool_msg_t -= dt


## Für Bilder (--welt=lm,event,caravan,giver,source,page): Held an die Stelle setzen, Ereignis starten …
func _shot_setup(what: String) -> void:
	var h = ex.hero
	var at := Vector2.INF
	for w0 in what.split(","):
		match w0:
			"lm":
				if lm_p != Vector2.INF:
					at = lm_p + (-lm_p).normalized() * (18.0 if w0 == "lm" else 10.0)
			"giver":
				if giver != null:
					at = giver_p + Vector2(2.5, 2.5)
			"page":
				if page_node != null:
					at = page_p + Vector2(3.0, 2.0)
			"source":
				if sources.size() > 0:
					at = sources[0].p + Vector2(2.2, 1.0)
			"caravan":
				_spawn_caravan(h.pos2())
				if caravan != null:
					car_stop = 999.0
					at = car_p + Vector2(3.5, 3.5)
			"event":
				start_event()
			"night", "abend", "morgen":
				debug_daytime("nacht" if w0 == "night" else w0)
			"tools":
				for k in DW.TOOLS:
					WS.give_tool(k)
	if at != Vector2.INF:
		h.global_position = Vector3(at.x, 0, at.y)
		ex.cam.snap()
	if "lm" in what.split(",") and lm_p != Vector2.INF:
		ex.cam.override_target = Vector3(lm_p.x, 2.0, lm_p.y)


# ================================================================= Tageslauf
func _target_weights() -> Dictionary:
	var out := {"morgen": 0.0, "tag": 0.0, "abend": 0.0, "nacht": 0.0}
	if forced != "":
		out[forced] = 1.0
		return out
	var ph: String = ex.phase
	var et: float = ex.explore_t
	if ph == "explore" and int(ex.dusk) > 0:
		out["nacht"] = 1.0
	elif ph == "explore" and et > D.EXP_DUSK_AFTER - DW.EXP_EVENING_LEAD:
		var k := clampf((et - (D.EXP_DUSK_AFTER - DW.EXP_EVENING_LEAD)) / 30.0, 0.0, 1.0)
		out["tag"] = 1.0 - k
		out["abend"] = k
	else:
		var k2 := clampf((t - DW.EXP_MORNING) / 20.0, 0.0, 1.0)
		out["morgen"] = 1.0 - k2
		out["tag"] = k2
	return out


func _update_daytime(dt: float, snap := false) -> void:
	var target := _target_weights()
	for m in Weather.MOODS:
		var cur: float = mood_w.get(m, target[m])
		mood_w[m] = target[m] if snap else move_toward(cur, target[m], dt * 0.25)
	var best := "tag"
	var bw := -1.0
	for m in Weather.MOODS:
		if mood_w[m] > bw:
			bw = mood_w[m]
			best = m
	daytime = best
	ex.daytime = best
	night_k = mood_w["nacht"]
	var sc := Color(0, 0, 0)
	var amb := Color(0, 0, 0)
	var fog := Color(0, 0, 0)
	var e := 0.0
	var pitch := 0.0
	var yaw := 0.0
	var ae := 0.0
	var glow := 0.0
	for m in Weather.MOODS:
		var k: float = mood_w[m]
		var s: Dictionary = Weather.MOOD[m]
		sc += s.sun * k
		amb += s.amb * k
		fog += s.fog * k
		e += s.e * k
		pitch += s.pitch * k
		yaw += s.yaw * k
		ae += s.ae * k
		glow += s.glow * k
	var th: Dictionary = ex.adef
	var bl := DW.EXP_MOOD_BLEND * (1.0 - night_k * 0.6)        # nachts zählt die Tageszeit mehr als das Gebiet
	sc = sc.lerp(Color(th.sun), bl)
	fog = fog.lerp(Color(th.fog), bl)
	e *= 1.0 - 0.25 * rain_k - 0.25 * dust_k - 0.15 * fog_k
	if ex.sun != null:
		ex.sun.light_color = sc
		ex.sun.light_energy = e
		ex.sun.rotation = Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0)
	var env: Environment = ex.world_env
	if env != null:
		env.ambient_light_color = amb
		env.ambient_light_energy = ae * (1.0 - 0.1 * rain_k)
		var fc := fog.lerp(Color(0.6, 0.65, 0.72), rain_k * 0.4).lerp(Color("D8B07A"), dust_k * 0.7).lerp(Color("C9D6D2"), fog_k * 0.6)
		if ak == "sumpf" and not ev.is_empty():
			fc = fc.lerp(Color("9FC27A"), 0.35)
		var ash := 1.0 if ak == "vulkan" and event_key() == "ausbruch" else 0.0
		fc = fc.lerp(Color("5E5250"), ash * 0.55)
		env.fog_light_color = fc
		env.fog_density = _base_fog + rain_k * 0.002 + dust_k * 0.016 + fog_k * 0.022 + ash * 0.01
		env.background_color = fc
	MK.mat_glow().set_shader_parameter("boost", glow)


## Testhilfe: Tageszeit festlegen ("" = Ablauf).
func debug_daytime(m: String) -> void:
	forced = m
	_update_daytime(0.0, true)


## Umgebungsklang: Gebiet am Tag, Nachtgeräusche nachts, Wetter des Ereignisses.
func _sounds() -> void:
	var day_db := -18.0 - 30.0 * night_k
	Sfx.loop("amb", "amb_x_" + ak if Sfx.has("amb_x_" + ak) else Sfx.ambience(ex.adef), day_db)
	if night_k > 0.05:
		Sfx.loop("amb_night", "amb_x_night", -24.0 + 8.0 * night_k)
	elif Sfx.looping("amb_night"):
		Sfx.stop("amb_night")


# ================================================================= Gebiets-Ereignisse
func event_active() -> bool:
	return not ev.is_empty()


func event_key() -> String:
	return String(ev.get("key", ""))


func _tick_event(dt: float, pp: Vector2) -> void:
	if ex.ended:
		return
	if ev.is_empty():
		if ex.phase == "explore":                     # Ereignisse gehören zur Phase „Erkunden“ (Kapitel 4.3)
			ev_next -= dt
			if ev_next <= 0.0:
				start_event()
		return
	if ex.phase != "explore" and ex.phase != "land":
		end_event()                                    # Großangriff oder Befreiung: kein Ereignis dazwischen
		return
	ev_left -= dt
	_ev_tick -= dt
	var tick := _ev_tick <= 0.0
	if tick:
		_ev_tick = 0.25
	match String(ev.key):
		"regen":
			rain_k = move_toward(rain_k, 1.0, dt / 4.0)
		"nebel":
			fog_k = move_toward(fog_k, 1.0, dt / 5.0)
		"sandsturm":
			dust_k = move_toward(dust_k, 1.0, dt / 3.0)
			if tick and ex.hero.alive and pp.distance_to(ex.outpost.C) > float(ev.safe_r):
				ex.hero.slow(float(ev.slow), 0.6)
		"ebbe":
			if ev_phase == 0 and ev_left < float(ev.dur) * 0.5:
				_flood_tide()
			if ev_phase == 1 and tick and ex.hero.alive and _near_water(pp, 2.6):
				ex.hero.slow(float(ev.flood_slow), 0.6)
		"giftnebel":
			_tick_clouds(dt, pp, tick)
		"lawine", "meteor", "ausbruch":
			_tick_strikes(dt, pp)
		"gewitter":
			rain_k = move_toward(rain_k, 1.0, dt / 3.0)
			_tick_strikes(dt, pp)
	if ev_left <= 0.0:
		end_event()


## Startet das Ereignis des Gebiets (auch für Admin und Tests).
func start_event() -> void:
	if not ev.is_empty() or not DW.EVENTS.has(ak):
		return
	ev = DW.EVENTS[ak]
	ev_left = float(ev.dur)
	ev_phase = 0
	_ev_spawned = 0
	_ev_tick = 0.0
	ev_count += 1
	WS.st().events = int(WS.st().events) + 1
	log.append("event:" + String(ev.key))
	P.toast.emit(String(ev.text))
	var pp: Vector2 = ex.hero.pos2()
	match String(ev.key):
		"regen":
			Sfx.play("ev_rain_start", -4.0)
			Sfx.loop("wx_ev", "ev_amb_rain", -14.0)
		"nebel":
			Sfx.play("ev_fog_rise", -4.0)
			Sfx.loop("wx_ev", "ev_amb_fog", -12.0)
			ex.horde.aggro_range = float(ev.aggro)
		"sandsturm":
			Sfx.play("ev_sandstorm", -3.0)
			Sfx.loop("wx_ev", "ev_amb_sandstorm", -10.0)
		"ebbe":
			Sfx.play("ev_tide_turn", -4.0)
			Sfx.loop("wx_ev", "ev_amb_tide", -14.0)
			_spawn_bonus(pp)
		"giftnebel":
			Sfx.play("ev_toxic_puff", -4.0)
			Sfx.loop("wx_ev", "ev_amb_toxic", -12.0)
			for i in int(ev.clouds):
				var c = pick_near(pp, 10.0, 26.0)
				if c == null:
					c = pp + Vector2.from_angle(rng.randf() * TAU) * 14.0
				_ev_items.append({"kind": "cloud", "p": c, "v": Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.9, 1.6), "n": _cloud_mesh(float(ev.radius)), "hurt": 0.0})
		"lawine":
			Sfx.play("ev_avalanche_warn", -3.0)
			Sfx.loop("wx_ev", "ev_amb_blizzard", -14.0)
		"meteor":
			Sfx.loop("wx_ev", "ev_amb_meteor", -12.0)
		"ausbruch":
			Sfx.play("ev_eruption", -2.0)
			Sfx.loop("wx_ev", "ev_amb_eruption", -10.0)
			if ex.vulkan != null:
				ex.vulkan.set_eruption(true)
		"gewitter":
			Sfx.play("ev_thunder", -2.0)
			Sfx.loop("wx_ev", "ev_amb_storm", -10.0)
			if ex.get("stadt") != null:
				ex.stadt.set_blackout(true)


func end_event() -> void:
	if ev.is_empty():
		return
	var k := String(ev.key)
	Sfx.stop("wx_ev")
	Sfx.play("ev_end", -8.0)
	ex.horde.aggro_range = _aggro0
	for it in _ev_items:
		if it.get("n") != null and is_instance_valid(it.n):
			it.n.queue_free()
		if it.get("ring") != null and is_instance_valid(it.ring):
			it.ring.queue_free()
	_ev_items.clear()
	if k == "ebbe" and ev_phase == 1:
		_ebb_back()
	if k == "regen":
		_after_rain()
	if k == "ausbruch" and ex.vulkan != null:
		ex.vulkan.set_eruption(false)
	if k == "gewitter" and ex.get("stadt") != null:
		ex.stadt.set_blackout(false)
	ev = {}
	ev_next = rng.randf_range(DW.EVENT_EVERY[0], DW.EVENT_EVERY[1])
	log.append("event_end:" + k)
	ex.state_changed.emit()


func _tick_particles(dt: float) -> void:
	if ev.is_empty() or (String(ev.key) != "regen" and String(ev.key) != "gewitter"):
		rain_k = move_toward(rain_k, 0.0, dt / 6.0)
	if ev.is_empty() or String(ev.key) != "sandsturm":
		dust_k = move_toward(dust_k, 0.0, dt / 4.0)
	if ev.is_empty() or String(ev.key) != "nebel":
		fog_k = move_toward(fog_k, 0.0, dt / 6.0)
	var focus: Vector3 = ex.cam.focus if ex.cam != null else Vector3.ZERO
	if _rain != null:
		_rain.emitting = rain_k > 0.15
		_rain.global_position = focus + Vector3(0, 14, 0)
	if _dust != null:
		_dust.emitting = dust_k > 0.15
		_dust.global_position = focus + Vector3(-18, 2.0, 0)
	if _rainbow != null and _rainbow.visible:
		_rainbow_t -= dt
		_rainbow_mat.set_shader_parameter("alpha", clampf(_rainbow_t / 20.0, 0.0, 1.0) * 0.6)
		if _rainbow_t <= 0.0:
			_rainbow.visible = false


## Sichtweite im Nebel des Erkundens (Nebel und Sandsturm: weniger).
func reveal_k() -> float:
	var k := 1.0
	if not ev.is_empty() and ev.has("reveal_k"):
		k = float(ev.reveal_k)
	return k


## Ertrag eines Schlags (Regen: mehr Holz).
func yield_k(res: String) -> float:
	if not ev.is_empty() and String(ev.key) == "regen" and res == "wood":
		return float(ev.wood_k)
	return 1.0


# ---- Regen: Regenbogen mit Münztopf
func _after_rain() -> void:
	var pp: Vector2 = ex.hero.pos2()
	var p = pick_near(pp, 18.0, 34.0)
	if p == null:
		return
	var n := _add_node("pot", p, 1)
	bonus_nodes.append(n)
	_rainbow.visible = true
	_rainbow_t = 60.0
	_rainbow.global_position = Vector3(p.x, 0.0, p.y)
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var to := cam.global_position - _rainbow.global_position
		_rainbow.rotation.y = atan2(to.x, to.z)
	ex.fx.ring(Vector3(p.x, 0.2, p.y), 3.0, D.C_GOLD, 0.8)
	P.toast.emit("Am Ende des Regenbogens steht ein Münztopf!")
	log.append("pot")


# ---- Küste: Ebbe gibt Schätze frei, Flut holt sie zurück
func _spawn_bonus(pp: Vector2) -> void:
	var water := PackedVector2Array()
	for i in ex.field.water.size():
		if ex.field.water[i] == 1:
			var c: Vector2 = ex.field.center(i)
			if c.distance_to(pp) < 60.0:
				water.append(c)
	var taken: Array = []
	for k in int(ev.bonus):
		var base: Vector2 = water[rng.randi() % water.size()] if water.size() > 0 else pp
		var p = pick_near(base, 4.0, 9.0, taken, 5.0)
		if p == null:
			p = pick_near(pp, 12.0, 30.0, taken, 5.0)
		if p == null:
			continue
		taken.append(p)
		var kind: String = ["coinpile", "scrap", "wreck"][k % 3]
		var n: Node3D = ResNode.new()
		ex.add_child(n)
		var nd: Dictionary = D.EXP_NODES[kind]
		n.setup(kind, p, roundf(rng.randf_range(float(nd.min), float(nd.max)) * float(ex.factor) * 1.5), 1, rng.randf() * TAU)
		n.cells = ex.field.block_circle_tracked(p, 0.9)
		ex.nodes.append(n)
		bonus_nodes.append(n)
		ex.fx.puff(Vector3(p.x, 0.5, p.y), Color(0.8, 0.9, 1.0), 10, 1.2)


func _flood_tide() -> void:
	ev_phase = 1
	P.toast.emit("Die Flut kommt zurück! Am Wasser kommst du nur langsam voran.")
	Sfx.play("ev_tide_turn", -2.0)
	for n in bonus_nodes:
		if is_instance_valid(n) and not n.gone and n.kind != "pot":
			n.gone = true
			n.visible = false
			if n.cells.size() > 0:
				ex.field.release_cells(n.cells)
				n.cells = PackedInt32Array()
			ex.fx.puff(n.global_position + Vector3(0, 0.4, 0), Color(0.7, 0.85, 1.0), 10, 1.2)
	if ex.water_mesh != null:
		var tw: Tween = ex.water_mesh.create_tween()
		tw.tween_property(ex.water_mesh, "position:y", 0.22, 3.0)


func _ebb_back() -> void:
	if ex.water_mesh != null:
		var tw: Tween = ex.water_mesh.create_tween()
		tw.tween_property(ex.water_mesh, "position:y", 0.0, 4.0)


func _near_water(p: Vector2, r: float) -> bool:
	var f = ex.field
	for o in [Vector2.ZERO, Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
		var q: Vector2 = p + o
		if f.in_bounds(q) and f.water[f.idx(q)] == 1:
			return true
	return false


# ---- Sumpf: treibende Giftwolken
func _cloud_mesh(r: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 0.9
	s.radial_segments = 16
	s.rings = 6
	m.mesh = s
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.55, 0.85, 0.25, 0.32)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ex.add_child(m)
	return m


func _tick_clouds(dt: float, pp: Vector2, tick: bool) -> void:
	var r := float(ev.radius)
	for c in _ev_items:
		if c.kind != "cloud":
			continue
		var p: Vector2 = c.p + c.v * dt
		if absf(p.x) > ex.HALFM - 10.0 or absf(p.y) > ex.HALFM - 10.0:
			c.v = -c.v
			p = c.p
		c.p = p
		var n: MeshInstance3D = c.n
		n.position = Vector3(p.x, 0.6 + sin(t * 1.3 + p.x) * 0.15, p.y)
		n.scale = Vector3.ONE * (1.0 + sin(t * 0.9 + p.y) * 0.06)
		if tick:
			if rng.randf() < 0.35:
				ex.fx.puff(Vector3(p.x + rng.randf_range(-r, r) * 0.6, 0.4, p.y + rng.randf_range(-r, r) * 0.6), Color(0.6, 0.9, 0.3), 3, 0.9)
			if ex.hero.alive and pp.distance_to(p) < r:
				ex.hero.hurt(ex.hero.max_hp * float(ev.dps) * 0.25)
				c.hurt = float(c.hurt) + 1.0
				Sfx.play("ev_toxic_hurt", -10.0, 1.0, 0.8)
			ex.horde.explode(p, r, 6.0 * float(ex.factor), {"knock": 0.0, "element": "poison"})


## Wie viele Treffer hat der Held schon im Giftnebel abbekommen? (Test)
func cloud_hits() -> int:
	var n := 0
	for c in _ev_items:
		if c.kind == "cloud":
			n += int(c.hurt)
	return n


# ---- Frostpass/Krater: Lawinen und Meteoriten mit Warnkreis
func _tick_strikes(dt: float, pp: Vector2) -> void:
	var n_all := int(ev.count)
	var every := float(ev.dur) / float(n_all + 1)
	if _ev_spawned < n_all and float(ev.dur) - ev_left >= every * (_ev_spawned + 0.5):
		_ev_spawned += 1
		var c = pick_near(pp, 2.0, 11.0)
		if c == null:
			c = pp + Vector2.from_angle(rng.randf() * TAU) * 5.0
		var r := float(ev.radius)
		var ring: MeshInstance3D = ex.ring_mesh(r, Color("FB3D54") if ev.key != "lawine" else Color("E6F4FF"))
		ring.position = Vector3(c.x, 0.15, c.y)
		_ev_items.append({"kind": "strike", "p": c, "r": r, "t": float(ev.warn), "ring": ring})
		if ev.key == "ausbruch":
			Sfx.play_at("ev_lavabomb_fall", Vector3(c.x, 0, c.y), -4.0, 1.0, 0.2)
		elif ev.key == "gewitter":
			Sfx.play_at("ev_thunder_warn", Vector3(c.x, 0, c.y), -5.0, 1.0, 0.2)
		elif ev.key == "meteor":
			Sfx.play_at("ev_meteor_fall", Vector3(c.x, 0, c.y), -4.0, 1.0, 0.2)
		else:
			Sfx.play_at("ev_avalanche_warn", Vector3(c.x, 0, c.y), -6.0, 1.0, 0.4)
	for i in range(_ev_items.size() - 1, -1, -1):
		var it: Dictionary = _ev_items[i]
		if it.kind != "strike":
			continue
		it.t = float(it.t) - dt
		var ring: MeshInstance3D = it.ring
		ring.scale = Vector3.ONE * (0.6 + 0.4 * absf(sin(t * 8.0)))
		if float(it.t) <= 0.0:
			_strike(it)
			ring.queue_free()
			_ev_items.remove_at(i)


func _strike(it: Dictionary) -> void:
	var c: Vector2 = it.p
	var r := float(it.r)
	var meteor: bool = ev.key == "meteor" or ev.key == "ausbruch"
	var p3 := Vector3(c.x, 0, c.y)
	var dmg := 260.0 * float(ex.hp_mult)
	if ev.key == "ausbruch":
		ex.blast(p3, r, dmg * 0.6, {"sfx": "ev_lavabomb_impact", "knock": 2.0}, Color(1.0, 0.42, 0.1))
	elif ev.key == "gewitter":
		# Paket Z2: Blitz – Blitzschaden (Maschinen +50 %), getroffene Maschinen gehen kurz aus
		ex.fx.lightning(p3 + Vector3(rng.randf_range(-2.0, 2.0), 22.0, rng.randf_range(-2.0, 2.0)), p3 + Vector3(0, 0.2, 0))
		ex.blast(p3, r, dmg * 0.5, {"sfx": "ev_lightning_strike", "knock": 1.0, "stun": float(ev.get("stun", 2.0)), "element": "blitz"}, Color(0.6, 0.85, 1.0))
	elif meteor:
		ex.blast(p3, r, dmg, {"sfx": "ev_meteor_impact", "knock": 2.0}, Color(1.0, 0.5, 0.2))
	else:
		ex.fx.explosion(p3 + Vector3(0, 0.6, 0), r, Color(0.95, 0.97, 1.0))
		Sfx.play_at("ev_avalanche", p3, -2.0, 1.0, 0.2)
		ex.horde.explode(c, r, dmg, {"knock": 2.5, "slow": 2.0, "element": "ice"})
	if ex.hero.alive and ex.hero.pos2().distance_to(c) < r:
		ex.hero.hurt(ex.hero.max_hp * float(ev.dmg))
		if not meteor:
			ex.hero.slow(0.5, 2.0)
		log.append("strike_hit")
	if meteor and not ex.field.is_solid(c):
		bonus_nodes.append(_add_node("lavabomb" if ev.key == "ausbruch" else "meteor", c, 1))
	elif ev.key == "gewitter" and rng.randf() < 0.5 and not ex.field.is_solid(c):
		bonus_nodes.append(_add_node("blitzakku", c, 1))      # Paket Z2: aufgeladener Akku bleibt liegen
	log.append("strike")


# ================================================================= Wahrzeichen
func _tick_landmark(pp: Vector2) -> void:
	if lm_p == Vector2.INF or lm_found or not ex.hero.alive:
		return
	if pp.distance_to(lm_p) < DW.LANDMARK_SEE + float(DW.LANDMARKS[ak].r) * DW.LANDMARK_SCALE:
		discover_landmark()


func discover_landmark() -> void:
	if lm_found:
		return
	lm_found = true
	var fresh := WS.see_landmark(ak)
	Sfx.play("landmark_discover", -3.0)
	ex.fx.confetti(Vector3(lm_p.x, 4.0, lm_p.y), 10)
	ex.fx.ring(Vector3(lm_p.x, 0.2, lm_p.y), 8.0, D.C_GOLD, 1.0)
	var nm := String(DW.LANDMARKS[ak].name)
	if fresh:
		P.add_hero_xp(ex.hero.key, DW.LANDMARK_XP)
	var got := WS.add_page(ak, 0)
	P.toast.emit("Wahrzeichen entdeckt: %s!%s" % [nm, " Eine Tagebuchseite lag dort." if got else ""])
	if got:
		_page_float(0, Vector3(lm_p.x, 4.5, lm_p.y))
	log.append("landmark")
	ex.state_changed.emit()


# ================================================================= Tagebuchseite
func _tick_page(_dt: float, pp: Vector2) -> void:
	if page_node == null or page_id < 0 or not ex.hero.alive:
		return
	var pg := Models.find(page_node, "bob_page_glow")
	if pg != null:
		pg.position.y = 0.62 + sin(t * 2.0) * 0.12              # schwebt
		pg.rotation.y = t * 1.2
	if pp.distance_to(page_p) < DW.JOURNAL_PICK_R:
		take_page()


func take_page() -> void:
	if page_id < 0:
		return
	var got := WS.add_page(ak, page_id)
	if got:
		P.add_hero_xp(ex.hero.key, DW.JOURNAL_XP)
	Sfx.play("journal_page", -3.0)
	_page_float(page_id, Vector3(page_p.x, 2.0, page_p.y))
	if page_node != null:
		page_node.queue_free()
		page_node = null
	page_id = -1
	log.append("page")
	ex.state_changed.emit()


func _page_float(i: int, at: Vector3) -> void:
	var pg: Array = DW.JOURNAL[ak][i]
	ex.fx.float_text(at, "Tagebuch: %s" % String(pg[0]), Color("F7E6B0"))
	P.toast.emit("Tagebuchseite „%s“ gefunden – lesen im Tagebuch (Weltkarte)." % String(pg[0]))


# ================================================================= Händler-Karawane
func _tick_caravan(dt: float, pp: Vector2) -> void:
	if not car_on:
		if ex.phase == "explore" and ex.explore_t > preload("res://src/liveops.gd").caravan_after(DW.CARAVAN_AFTER) and ex.mission != "befreiung":     # Paket L: Händlerwoche
			_spawn_caravan(pp)
		return
	if caravan == null:
		return
	var near := pp.distance_to(car_p) < 12.0
	if near:
		car_stop = maxf(car_stop, 2.5)                       # wartet auf den Helden
	if car_stop > 0.0:
		car_stop -= dt
	else:
		car_go -= dt
		if car_go <= 0.0:
			car_go = DW.CARAVAN_STOP_EVERY
			car_stop = DW.CARAVAN_STOP_TIME
			Sfx.play_at("caravan_bell", Vector3(car_p.x, 0, car_p.y), -6.0, 1.0, 1.0)
		var tgt: Vector2 = car_path[car_i]
		var to := tgt - car_p
		var step := DW.CARAVAN_SPEED * dt
		if to.length() <= step:
			car_p = tgt
			car_i = (car_i + 1) % car_path.size()
		else:
			car_p += to.normalized() * step
			var yaw := atan2(to.x, to.y)
			caravan.rotation.y = lerp_angle(caravan.rotation.y, yaw, minf(1.0, dt * 4.0))
		caravan.position = Vector3(car_p.x, 0, car_p.y)
		for wh in _wheels:
			(wh as Node3D).rotation.x += step / 0.4
	if _cart != null:
		var back: Vector3 = caravan.global_transform.basis.z * -3.4
		var want := caravan.global_position + back
		_cart.global_position = _cart.global_position.lerp(want, minf(1.0, dt * 3.0)) if _cart.global_position.distance_to(want) < 4.0 else want
		var d2 := caravan.global_position - _cart.global_position
		if d2.length() > 0.1:
			_cart.rotation.y = atan2(d2.x, d2.z)
	var can: bool = pp.distance_to(car_p) < DW.CARAVAN_TRADE_R and ex.hero.alive and not ex.hero.mounted
	if can:
		_show_panel()
	else:
		_close_panel()


func _spawn_caravan(pp: Vector2) -> void:
	car_on = true
	var r := D.EXP_RING_LAND + 18.0
	var pts := PackedVector2Array()
	for k in 40:
		var a := k * TAU / 40.0
		var q := Vector2(cos(a), sin(a)) * r
		if ex.field.blocks_player(q):
			var found := false
			for dd in [2.0, -2.0, 4.0, -4.0, 6.0, -6.0]:
				var q2: Vector2 = Vector2(cos(a), sin(a)) * (r + dd)
				if not ex.field.blocks_player(q2):
					q = q2
					found = true
					break
			if not found:
				continue
		pts.append(q)
	if pts.size() < 8:
		return
	car_path = pts
	var best := 0
	for i in pts.size():
		if pts[i].distance_to(pp) < pts[best].distance_to(pp):
			best = i
	car_i = (best + 6) % pts.size()                      # taucht ein Stück vor dem Helden auf
	car_p = pts[car_i]
	caravan = Models.glb("o_truck") if Models.has_glb("o_truck") else Node3D.new()
	caravan.position = Vector3(car_p.x, 0, car_p.y)
	ex.add_child(caravan)
	for wn in ["wheel_fl", "wheel_fr", "wheel_bl", "wheel_br"]:
		var wh := Models.find(caravan, wn)
		if wh != null:
			_wheels.append(wh)
	if Models.has_glb("o_trader"):
		_cart = Models.glb("o_trader")
		ex.add_child(_cart)
		_cart.position = caravan.position + Vector3(0, 0, -3.4)
	car_stop = DW.CARAVAN_STOP_TIME
	Sfx.play("caravan_bell", -3.0)
	P.toast.emit("Eine Händler-Karawane zieht durch das Gebiet – sie verkauft Werkzeug und Eier.")
	log.append("caravan")
	ex.state_changed.emit()


func caravan_price(kind: String) -> int:
	var f := float(ex.factor) * preload("res://src/liveops.gd").caravan_mult()      # Paket L: Händlerwoche
	match kind:
		"tool":
			var tk := WS.tool_for_area(area)
			return int(ceil(float(DW.TOOLS[tk].price) * f)) if tk != "" else 0
		_:
			return int(ceil(float(DW.CARAVAN_OFFERS.get(kind, 50)) * f))


## Kauft bei der Karawane mit Feldmünzen. Rückgabe: "" oder Grund.
func buy(kind: String) -> String:
	var price := caravan_price(kind)
	if float(ex.loot.get("coins", 0.0)) < float(price):
		return "Zu wenig Feldmünzen (%d nötig)" % price
	match kind:
		"tool":
			var tk := WS.tool_for_area(area)
			if tk == "" or WS.has_tool(tk):
				return "Das Werkzeug hast du schon"
			WS.give_tool(tk)
			Sfx.play("tool_get", -3.0)
			P.toast.emit("Gekauft: %s. %s" % [DW.TOOLS[tk].name, DW.TOOLS[tk].text])
		"egg":
			if WS.eggs().size() >= DW.EGG_MAX:
				return "Kein Platz für ein weiteres Ei (höchstens %d)" % DW.EGG_MAX
			WS.add_egg("caravan", "", rng)
			Sfx.play("egg_found", -3.0)
			P.toast.emit("Ein Begleiter-Ei! Es schlüpft im Nest der Basis (Bildschirm „Begleiter“).")
		"rare":
			var r := "shards" if area >= 4 else "parts"
			if ex.add_pack(r, 3.0) < 1.0:
				return "Der Rucksack ist voll"
			Sfx.play("caravan_trade", -4.0)
		"fuel":
			if ex.add_pack("fuel", 20.0 * float(ex.factor)) < 1.0:
				return "Der Rucksack ist voll"
			Sfx.play("caravan_trade", -4.0)
		_:
			return "Unbekannt"
	ex.loot["coins"] = float(ex.loot.get("coins", 0.0)) - float(price)
	ex._recalc_weight()
	log.append("buy:" + kind)
	_panel_sig = ""
	ex.state_changed.emit()
	return ""


func _offers() -> Array:
	var out: Array = []
	var tk := WS.tool_for_area(area)
	if tk != "" and not WS.has_tool(tk):
		out.append(["tool", DW.TOOLS[tk].icon, String(DW.TOOLS[tk].name), String(DW.TOOLS[tk].text)])
	out.append(["egg", "p_egg", "Begleiter-Ei", "Schlüpft nach %d Stunden im Nest der Basis." % int(DW.EGG_HATCH_HOURS)])
	out.append(["rare", "res_shards" if area >= 4 else "res_parts", "Seltene Ladung", "3 %s" % D.RES_NAME["shards" if area >= 4 else "parts"]])
	out.append(["fuel", "res_fuel", "Treibstoff", "%d Treibstoff" % int(20.0 * float(ex.factor))])
	return out


func _show_panel() -> void:
	if G.main == null or G.main.hud == null:
		return
	var sig := "%d|%s|%d" % [int(ex.loot.get("coins", 0.0)), str(WS.st().tools), WS.eggs().size()]
	if _panel != null and is_instance_valid(_panel) and sig == _panel_sig:
		return
	_close_panel()
	_panel_sig = sig
	var v := UI.vbox(8)
	v.add_child(UI.hbox(10, [UI.pic("o_trader", 48.0, "ui_crate"), UI.label("Händler-Karawane", 26, UI.GOLD), UI.spacer(true), UI.icon("coins", 30), UI.gold(UI.fmt(int(ex.loot.get("coins", 0.0))), 24)]))
	for o in _offers():
		var price := caravan_price(String(o[0]))
		var kind := String(o[0])
		var row := UI.hbox(10, [UI.pic(String(o[1]), 44.0, "ui_crate"), UI.vbox(2, [UI.label(String(o[2]), 22), UI.text(String(o[3]), 17, UI.TEXT, 300)]), UI.spacer(true)])
		var b := UI.button("%d" % price, func():
			var why := buy(kind)
			if why != "":
				P.toast.emit(why)
				Sfx.play("ui_error", -6.0), "green", 22, "res_coins")
		b.custom_minimum_size = Vector2(130, 56)
		UI.disable(b, float(ex.loot.get("coins", 0.0)) < float(price))
		row.add_child(b)
		v.add_child(row)
	var p := UI.panel(v, UI.NAVY, UI.EDGE, 18, 14)
	p.custom_minimum_size = Vector2(560, 0)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_bottom", 190)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.size_flags_vertical = Control.SIZE_SHRINK_END
	m.add_child(p)
	G.main.hud.root.add_child(m)
	_panel = m


func _close_panel() -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null
	_panel_sig = ""


func panel_open() -> bool:
	return _panel != null and is_instance_valid(_panel)


# ================================================================= Nebenquest
func _quest_def() -> Dictionary:
	return DW.QUESTS.get(ak, {})


func _update_giver_sign() -> void:
	if _giver_sign == null:
		return
	var q := WS.quest(ak)
	var qd := _quest_def()
	match int(q.state):
		0:
			_giver_sign.text = "!"
		1:
			_giver_sign.text = "✓" if int(q.got) >= int(qd.n) else "%d/%d" % [int(q.got), int(qd.n)]
		_:
			_giver_sign.text = ""


func _place_items() -> void:
	if _q_placed:
		return
	_q_placed = true
	var qd := _quest_def()
	var left := int(qd.n) - int(WS.quest(ak).got)
	var taken: Array = [ex.START, lm_p, page_p]
	var qr := RandomNumberGenerator.new()
	qr.seed = _rng_seed("items%d" % P.day_index())
	_real_field(func(): _place_items_on(left, taken, qd, qr))


func _place_items_on(left: int, taken: Array, qd: Dictionary, qr: RandomNumberGenerator) -> void:
	for i in left:
		var p = ex._pick(D.EXP_RING_LAND + 10.0, 16.0, taken, D.EXP_RING_MID + 25.0, qr)
		if p == null:
			continue
		taken.append(p)
		var n: Node3D = Models.glb(String(qd.model)) if Models.has_glb(String(qd.model)) else Node3D.new()
		n.position = Vector3(p.x, 0, p.y)
		n.scale = Vector3.ONE * 1.6
		ex.add_child(n)
		var ring: MeshInstance3D = ex.ring_mesh(1.1, D.C_GOLD)
		ring.position = Vector3(p.x, 0.12, p.y)
		q_items.append({"n": n, "ring": ring, "p": p, "done": false})


func _tick_quest(dt: float, pp: Vector2) -> void:
	if giver == null:
		return
	giver.tick(dt)
	var q := WS.quest(ak)
	var qd := _quest_def()
	var dg := pp.distance_to(giver_p)
	if ex.hero.alive and dg < DW.QUEST_TALK_R and int(q.state) < 2:
		giver.look_target = Vector3(pp.x, 1.5, pp.y)
		if _talk_ready:
			talk_k += dt / DW.QUEST_TALK_TIME
			if talk_k >= 1.0:
				talk_k = 0.0
				_talk_ready = false
				talk()
	else:
		talk_k = 0.0
		giver.look_target = null
		if dg > DW.QUEST_TALK_R + 2.0:
			_talk_ready = true
	if int(q.state) == 1:
		for it in q_items:
			if not it.done and ex.hero.alive and pp.distance_to(it.p) < DW.QUEST_PICK_R:
				it.done = true
				it.n.queue_free()
				it.ring.queue_free()
				q.got = int(q.got) + 1
				P.mark()
				Sfx.play("quest_step", -4.0)
				ex.fx.float_text(Vector3(it.p.x, 2.2, it.p.y), "%s %d/%d" % [String(qd.item), int(q.got), int(qd.n)], D.C_GOLD)
				if int(q.got) >= int(qd.n):
					P.toast.emit("Alle %s gefunden – zurück zu %s!" % [String(qd.item), String(qd.giver)])
				_update_giver_sign()
				log.append("quest_item")
				ex.state_changed.emit()


## Mit dem Auftraggeber sprechen: annehmen, Stand nennen oder abschließen.
func talk() -> void:
	var q := WS.quest(ak)
	var qd := _quest_def()
	if qd.is_empty():
		return
	giver.play("wave", false)
	match int(q.state):
		0:
			q.state = 1
			P.mark()
			Sfx.play("quest_new", -3.0)
			P.toast.emit("%s – %s: %s" % [String(qd.title), String(qd.giver), String(qd.intro)])
			_place_items()
			log.append("quest_accept")
		1:
			if int(q.got) >= int(qd.n):
				_quest_done()
			else:
				P.toast.emit("%s: Noch %d %s zu finden." % [String(qd.giver), int(qd.n) - int(q.got), String(qd.item)])
	_update_giver_sign()
	ex.state_changed.emit()


func _quest_done() -> void:
	var q := WS.quest(ak)
	var qd := _quest_def()
	q.state = 2
	ex.add_pack("coins", float(qd.coins) * float(ex.factor))
	var tk := WS.tool_for_area(area)
	WS.give_tool(tk)
	var page := WS.add_page(ak, 3)
	P.add_hero_xp(ex.hero.key, DW.QUEST_XP)
	P.count_up("side_quests", 1)
	P.mark()
	Sfx.play("quest_done", -3.0)
	Sfx.play("tool_get", -6.0)
	giver.cheer(2.0)
	ex.fx.confetti(Vector3(giver_p.x, 2.0, giver_p.y), 6)
	P.toast.emit("%s: %s" % [String(qd.giver), String(qd.done)])
	if page:
		_page_float(3, Vector3(giver_p.x, 3.2, giver_p.y))
	log.append("quest_done")


## Zeilen für die Aufgabenliste links (Expedition).
func quest_lines() -> Array:
	var out: Array = []
	var qd := _quest_def()
	if not qd.is_empty() and giver != null:
		var q := WS.quest(ak)
		match int(q.state):
			0:
				out.append(["%s: sprich mit %s" % [String(qd.title), String(qd.giver)], false])
			1:
				out.append(["%s: %d/%d %s" % [String(qd.title), int(q.got), int(qd.n), String(qd.item)], false])
			2:
				out.append([String(qd.title), true])
	if lm_p != Vector2.INF and not lm_found and ex.phase == "explore":
		out.append(["Wahrzeichen: %s" % String(DW.LANDMARKS[ak].name), false])
	if not ev.is_empty():
		out.append(["%s: noch %d s" % [String(ev.name), int(ceil(ev_left))], false])
	return out


## Punkte für die Übersichtskarte.
func map_points(out: Array) -> void:
	if lm_p != Vector2.INF and (lm_found or ex._seen(lm_p)):
		out.append([lm_p, "goal"])
	if page_node != null and ex._seen(page_p):
		out.append([page_p, "goal"])
	if giver != null:
		out.append([giver_p, "goal"])
	for it in q_items:
		if not it.done and ex._seen(it.p):
			out.append([it.p, "goal"])
	if caravan != null:
		out.append([car_p, "goal"])
	for it in _ev_items:
		if it.kind == "strike":
			out.append([it.p, "raid"])
	for n in bonus_nodes:
		if is_instance_valid(n) and not n.gone:
			out.append([n.p, "pile", D.RES_COLOR.get(n.res, D.C_GOLD)])


# ================================================================= Quellen mit Werkzeug
## Darf diese Quelle abgebaut werden? "" = ja, sonst der Name des fehlenden Werkzeugs.
func tool_missing(n) -> String:
	var tk := String(n.def.get("tool", ""))
	if tk == "" or WS.has_tool(tk):
		return ""
	return String(DW.TOOLS[tk].name)


## Hinweis, wenn der Held vor einer Quelle steht, für die ihm das Werkzeug fehlt.
func tool_hint(n) -> void:
	if _tool_msg_t > 0.0:
		return
	_tool_msg_t = 4.0
	var miss := tool_missing(n)
	ex.fx.float_text(n.global_position + Vector3(0, 2.6, 0), "Werkzeug fehlt: %s" % miss, Color("FB3D54"))
	P.toast.emit("%s: Dafür brauchst du „%s“ – von der Händler-Karawane oder als Lohn der Nebenquest." % [String(n.def.name), miss])
	Sfx.play("tool_missing", -6.0)


## Wirkung eines Schlags an einer gebietseigenen Quelle (Heilen, Tempo).
func on_hit(n) -> void:
	var b: Dictionary = n.def.get("buff", {})
	if b.is_empty() or not ex.hero.alive:
		return
	if b.has("heal"):
		ex.hero.heal(ex.hero.max_hp * float(b.heal))
	if b.has("speed"):
		ex.hero.speed_k = maxf(ex.hero.speed_k, float(b.speed[0]))
		ex.hero.speed_t = maxf(ex.hero.speed_t, float(b.speed[1]))


# ================================================================= Teilchen
func _make_rain() -> void:
	var p := CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.035, 0.7, 0.035)
	p.mesh = bm
	p.amount = [160, 300, 480][G.quality()]
	p.lifetime = 0.55
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(26, 1, 22)
	p.direction = Vector3(0, -1, 0)
	p.spread = 4.0
	p.initial_velocity_min = 12.0
	p.initial_velocity_max = 15.0
	p.gravity = Vector3(1.5, -32, 0.6)
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


func _make_dust() -> void:
	var p := CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.08, 0.08)
	p.mesh = bm
	p.amount = [120, 220, 360][G.quality()]
	p.lifetime = 2.2
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(4, 3, 26)
	p.direction = Vector3(1, 0.05, 0.15)
	p.spread = 8.0
	p.initial_velocity_min = 14.0
	p.initial_velocity_max = 22.0
	p.gravity = Vector3(0, -0.5, 0)
	p.local_coords = false
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.92, 0.78, 0.52, 0.55)
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emitting = false
	add_child(p)
	_dust = p


func _make_rainbow() -> void:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(44, 22)
	qm.center_offset = Vector3(0, 11, 0)
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
	ALPHA = alpha * sin(t * 3.14159) * smoothstep(0.0, 0.1, p.y);
}
"""
	_rainbow_mat.shader = sh
	mi.material_override = _rainbow_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	_rainbow = mi
