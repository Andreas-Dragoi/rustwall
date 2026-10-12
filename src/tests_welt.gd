extends RefCounted
## Prüfungen für das Paket Welt (V5): Musik und Ton (Stücke, Gefahr-Lage, Stinger, Mischpult, Rufe, OGG),
## Gebiete (Wahrzeichen, Tageslauf, sieben Ereignisse mit Wirkung, Quellen mit Werkzeug, Tagebuch, Karawane,
## Nebenquest, gefangener Begleiter in der Landezone), Begleiter (Köder, Eier, Kisten, Vorschau, Blasen holen),
## Bewohner (echte Bäume, Tagesablauf, Wünsche, Jubel im Gehen, Hühner) und Übungsplatz.
## Aufruf aus tests.gd (--selftest) oder allein mit --autotest=welt.

const D = preload("res://src/data.gd")
const DW = preload("res://src/data_welt.gd")
const WS = preload("res://src/welt_state.gd")
const CD = preload("res://src/companion_data.gd")
const Models = preload("res://src/models.gd")
const CompanionPose = preload("res://src/companion_pose.gd")
const NpcBoard = preload("res://src/npc_board.gd")

var T: Node                      # tests.gd (für _check und _wait)


func _init(tests: Node) -> void:
	T = tests


func run() -> void:
	_data()
	_state()
	_sound()
	await _music()
	await _areas()
	await _events()
	await _quest_caravan()
	await _companions()
	await _npcs()
	await _training()
	await _screens()
	_fresh()
	G.main.goto_base()
	await T._wait(0.3)


func _fresh() -> void:
	P.new_game()
	P.no_save = true
	P.d.level = 60
	for i in D.AREAS.size():
		for dd in 3:
			P.d.areas.boss[i][dd] = true
	P.d.outposts = {}
	P._ensure_fields()


func _start(area: int, explore := true) -> Node:
	G.autotest = ""
	G.main.start_expedition(area, "expedition", 0)
	await T._wait(0.4)
	var e = G.main.world
	if explore:
		e.admin_outpost_done()
		await T._wait(0.3)
	return e


# ---------------------------------------------------------------- Daten
func _data() -> void:
	T._check(DW.EVENTS.size() == D.AREAS.size() and DW.LANDMARKS.size() == D.AREAS.size() and DW.QUESTS.size() == D.AREAS.size(), "Welt: je Gebiet Ereignis, Wahrzeichen, Nebenquest")
	for a in D.AREAS:
		var ak := String(a.key)
		T._check(DW.JOURNAL.has(ak) and DW.JOURNAL[ak].size() >= 3 and DW.JOURNAL[ak].size() <= 5, "Tagebuch %s: 3–5 Seiten" % ak)
		T._check(Models.has_glb(String(DW.LANDMARKS[ak].model)), "Wahrzeichen-Modell %s" % DW.LANDMARKS[ak].model)
		var src: Dictionary = DW.SOURCES.get("src_" + ak, {})
		T._check(not src.is_empty() and Models.has_glb(String(src.model)) and DW.TOOLS.has(String(src.tool)), "Quelle und Werkzeug in %s" % ak)
		T._check(ResourceLoader.exists("res://icons/%s.png" % DW.TOOLS[String(src.tool)].icon), "Werkzeug-Symbol %s" % src.tool)
	for m in ["p_journal", "p_egg", "p_egg_nest", "p_dummy", "n_meteor", "c_barrow"]:
		T._check(Models.has_glb(m), "Modell %s" % m)


# ---------------------------------------------------------------- Spielstand
func _state() -> void:
	_fresh()
	T._check(P.d.has("welt") and P.d.welt.has("pages") and P.d.welt.eggs is Array, "Welt-Felder im Spielstand")
	T._check(WS.add_page("forst", 1) and not WS.add_page("forst", 1) and WS.page_total() == 1, "Tagebuchseite einmal")
	T._check(WS.next_map_page("forst") == 2, "nächste Fundseite")
	T._check(not WS.has_tool("pump") and WS.give_tool("pump") and WS.has_tool("pump"), "Werkzeug geben")
	var snap: Dictionary = JSON.parse_string(JSON.stringify(P.d))
	P.d = snap
	P._ensure_fields()
	T._check(WS.has_page("forst", 1) and WS.has_tool("pump"), "Tagebuch und Werkzeug überstehen Speichern/Laden")
	# Eier: höchstens drei, schlüpfen nach Ablauf
	var ks: Array = []
	for i in 4:
		ks.append(WS.add_egg("test"))
	T._check(ks[3] == "" and WS.eggs().size() == DW.EGG_MAX, "höchstens %d Eier" % DW.EGG_MAX)
	T._check(WS.hatch(0) == "" and WS.egg_left(0) > 0.0, "Ei braucht Zeit")
	var k0 := String(WS.eggs()[0].key)
	var had := CD.owned(k0)
	WS.eggs()[0].t = P.now() - DW.EGG_HATCH_HOURS * 3600.0 - 1.0
	var txt := WS.hatch(0)
	T._check(txt != "" and CD.owned(k0) and WS.eggs().size() == DW.EGG_MAX - 1, "Ei schlüpft: %s (%s)" % [k0, "schon da" if had else "neu"])
	# seltene Kiste mit Ei (ersetzt ein Stück, Anzahl bleibt)
	P.d.welt.eggs = []
	WS.force_egg = true
	P.d.chests["boss"] = 1
	var out: Array = P.open_chest("boss")
	WS.force_egg = false
	var egg_n := 0
	for pc in out:
		if String(pc.kind) == "egg":
			egg_n += 1
	T._check(egg_n == 1 and out.size() == int(D.CHESTS.boss.count) and WS.eggs().size() == 1, "Bosskiste mit Begleiter-Ei (%d Stücke)" % out.size())


# ---------------------------------------------------------------- Ton
func _sound() -> void:
	T._check(AudioServer.get_bus_index("Ambient") >= 0 and AudioServer.get_bus_index("Voice") >= 0, "Mischpult: Kanäle Umgebung und Stimmen")
	for hk in D.HERO_ORDER:
		var n := 0
		for k in Sfx.VOICE_KINDS:
			if Sfx.has("v_%s_%s" % [hk, k]):
				n += 1
		T._check(n >= 6 and n <= 8, "Rufe %s: %d" % [hk, n])
	T._check(Sfx.has("amb_x_staub") and Sfx.has("ev_amb_sandstorm") and Sfx.has("journal_page"), "neue Klänge (OGG und WAV) laden")
	T._check(Sfx._bus_name_for("v_jona_hurt") == "Voice" and Sfx._bus_name_for("amb") == "Ambient" and Sfx._bus_name_for("wx_ev") == "Ambient" and Sfx._bus_name_for("click") == "SFX", "Klänge auf die richtigen Kanäle")
	P.d.settings["amb"] = 0.0
	P.d.settings["voice"] = 0.5
	Sfx._read_mixer()
	T._check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Ambient")) and absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Voice")) - linear_to_db(0.5)) < 0.1, "Regler Umgebung und Stimmen wirken")
	P.d.settings["amb"] = 0.8
	P.d.settings["voice"] = 0.8
	Sfx._read_mixer()


func _music() -> void:
	var need := ["menu", "boss"]
	for a in D.AREAS:
		need.append("area_" + String(a.key))
	for k in need:
		var i: int = Music.track_index(k)
		T._check(i >= 0 and ResourceLoader.exists(Music.DIR + String(Music.TRACKS[i].file)), "Musik %s vorhanden" % k)
		if i >= 0 and Music.TRACKS[i].has("layer"):
			T._check(ResourceLoader.exists(Music.DIR + String(Music.TRACKS[i].layer)), "Gefahr-Lage zu %s" % k)
	T._check(Music.has_stinger("win") and Music.has_stinger("lose"), "Sieg- und Niederlage-Stinger")
	var n0: int = Music.stingers_played.size()
	Sfx.play("win")
	T._check(Music.stingers_played.size() == n0 + 1, "Sieg spielt den Stinger statt des Klangs")


# ---------------------------------------------------------------- Gebiete
func _areas() -> void:
	_fresh()
	P.d.vehicle_sel = ""
	var e = await _start(2)
	var wl = e.welt
	T._check(wl != null and wl.lm_p != Vector2.INF and wl.landmark != null, "Staubebene: Wahrzeichen steht")
	T._check(e.field.is_solid(wl.lm_p), "Wahrzeichen sperrt seinen Platz")
	for i in 30:
		await T._wait(1.0)
		if Music.current() == "area_staub":
			break
	T._check(Music.current() == "area_staub", "Musik der Staubebene läuft (%s)" % Music.debug_state())
	T._check(Music.layer_db() <= 0.0, "Gefahr-Lage gehört zum Stück")
	# Tageslauf
	T._check(e.daytime == "tag", "Tests: Tag")
	var e_day: float = e.sun.light_energy
	wl.debug_daytime("nacht")
	T._check(e.daytime == "nacht" and e.is_night() and e.sun.light_energy < e_day, "Nacht in der Expedition (Licht %.2f → %.2f)" % [e_day, e.sun.light_energy])
	wl.debug_daytime("tag")
	# Quelle mit Werkzeug
	T._check(wl.sources.size() >= 2, "gebietseigene Quellen (%d)" % wl.sources.size())
	var src = wl.sources[0]
	T._check(e.node_locked(src), "Wasserkaktus ohne Zapfhahn gesperrt")
	e.hero.dismount()
	var stand: Vector2 = e._stand(src, src.p + Vector2(3, 0))
	e.hero.global_position = Vector3(stand.x, 0, stand.y)
	e.hero.test_wish = Vector2.ZERO
	var c0: float = float(e.loot.get("coins", 0.0))
	await T._wait(2.0)
	T._check(float(e.loot.get("coins", 0.0)) <= c0 + 0.01 and not src.gone and src.left >= src.total - 0.01, "ohne Werkzeug kein Abbau")
	WS.give_tool("tap")
	e.hero.hp = e.hero.max_hp * 0.5
	await T._wait(4.0)
	T._check(src.left < src.total, "mit Zapfhahn: Abbau (%.0f von %.0f übrig)" % [src.left, src.total])
	T._check(e.hero.hp > e.hero.max_hp * 0.55, "Kaktuswasser heilt")
	e.hero.test_wish = null
	# Wahrzeichen entdecken
	e.hero.global_position = Vector3(wl.lm_p.x + 8.0, 0, wl.lm_p.y + 8.0)
	await T._wait(0.5)
	T._check(WS.landmark_seen("staub") and WS.has_page("staub", 0), "Wahrzeichen entdeckt: Tagebuchseite 0")
	# Tagebuchseite im Gebiet
	if wl.page_node != null:
		var pid: int = wl.page_id
		e.hero.global_position = Vector3(wl.page_p.x, 0, wl.page_p.y)
		await T._wait(0.4)
		T._check(WS.has_page("staub", pid) and wl.page_node == null, "Tagebuchseite %d aufgehoben" % pid)
	else:
		T._check(false, "Tagebuchseite liegt im Gebiet")
	e.abort()
	await T._wait(0.3)
	# gefangener Begleiter beim ersten Besuch in der Landezone (Grüntal: Eule)
	_fresh()
	e = await _start(0, false)
	var pet = null
	for q in e.pois:
		if q.kind == "pet":
			pet = q
	T._check(pet != null and pet.p.length() < D.EXP_RING_LAND, "erster Besuch: Käfig in der Landezone")
	if pet != null:
		e.hero.global_position = Vector3(pet.p.x + 1.0, 0, pet.p.y)
		await T._wait(3.4)
		T._check(pet.done and CD.owned("eule"), "Käfig auch vor dem Erkunden zu öffnen")
	e.abort()
	await T._wait(0.3)


# ---------------------------------------------------------------- Ereignisse (alle sieben)
func _events() -> void:
	_fresh()
	for area in D.AREAS.size():
		var e = await _start(area)
		var wl = e.welt
		var ak := String(D.AREAS[area].key)
		wl.start_event()
		var k: String = wl.event_key()
		T._check(wl.event_active() and k == String(DW.EVENTS[ak].key), "%s: Ereignis %s startet" % [ak, k])
		var pp: Vector2 = e.hero.pos2()
		match k:
			"regen":
				T._check(wl.yield_k("wood") > 1.4, "Regen: mehr Holz")
				wl.end_event()
				T._check(wl.bonus_nodes.size() >= 1 and String(wl.bonus_nodes[0].kind) == "pot", "Regen vorbei: Münztopf am Regenbogen")
			"nebel":
				await T._wait(0.3)
				T._check(e.horde.aggro_range < 10.0 and wl.reveal_k() < 0.6, "Nebel: Gegner bemerken spät, weniger Sicht")
				wl.end_event()
				T._check(e.horde.aggro_range > 12.0, "Nebel vorbei: Wachsamkeit wieder normal")
			"sandsturm":
				e.hero.global_position = Vector3(e.outpost.C.x + 30.0, 0, e.outpost.C.y)
				e.hero.dismount()
				await T._wait(0.6)
				T._check(e.hero.speed_k < 0.9 and wl.reveal_k() < 0.6, "Sandsturm: langsamer, weniger Sicht")
				wl.end_event()
			"ebbe":
				var nb: int = wl.bonus_nodes.size()
				T._check(nb >= 2, "Ebbe: Schätze liegen frei (%d)" % nb)
				wl.ev_left = float(DW.EVENTS.kueste.dur) * 0.45
				await T._wait(0.3)
				var gone := 0
				for n in wl.bonus_nodes:
					if n.gone:
						gone += 1
				T._check(wl.ev_phase == 1 and gone == nb, "Flut holt die Schätze zurück")
				wl.end_event()
			"giftnebel":
				var c: Dictionary = wl._ev_items[0]
				var hp0: float = e.hero.hp
				for i in 12:
					e.hero.global_position = Vector3(c.p.x, 0, c.p.y)
					await T._wait(0.1)
				T._check(wl.cloud_hits() > 0 and e.hero.hp < hp0, "Giftnebel schadet (%d Treffer)" % wl.cloud_hits())
				e.hero.hp = e.hero.max_hp
				wl.end_event()
			"lawine", "meteor", "ausbruch":
				var t0 := 0
				while wl.event_active() and t0 < 60:
					await T._wait(1.0)
					t0 += 1
				var strikes: int = wl.log.count("strike")
				T._check(strikes >= int(DW.EVENTS[ak].count) - 1, "%s: %d Einschläge" % [k, strikes])
				if k == "meteor":
					T._check(wl.bonus_nodes.size() >= 1 and String(wl.bonus_nodes[0].kind) == "meteor", "Meteorit bleibt als Quelle liegen")
		T._check(not wl.event_active() and (k != "nebel" or e.horde.aggro_range > 12.0), "%s: Ereignis endet" % ak)
		e.abort()
		await T._wait(0.25)


# ---------------------------------------------------------------- Nebenquest und Karawane
func _quest_caravan() -> void:
	_fresh()
	var e = await _start(4)
	var wl = e.welt
	var q: Dictionary = WS.quest("sumpf")
	T._check(wl.giver != null and q.state == 0, "Sumpf: Auftraggeber wartet")
	e.hero.global_position = Vector3(wl.giver_p.x + 1.0, 0, wl.giver_p.y)
	await T._wait(1.8)
	q = WS.quest("sumpf")
	T._check(q.state == 1 and wl.q_items.size() == 3, "Nebenquest angenommen, drei Fundstücke liegen aus")
	for it in wl.q_items:
		e.hero.global_position = Vector3(it.p.x, 0, it.p.y)
		await T._wait(0.25)
	T._check(int(WS.quest("sumpf").got) == 3, "alle Fundstücke gesammelt")
	e.hero.global_position = Vector3(wl.giver_p.x + 10.0, 0, wl.giver_p.y)
	await T._wait(0.3)
	e.hero.global_position = Vector3(wl.giver_p.x + 1.0, 0, wl.giver_p.y)
	await T._wait(1.8)
	T._check(int(WS.quest("sumpf").state) == 2 and WS.has_tool("pump") and WS.has_page("sumpf", 3), "Nebenquest erledigt: Handpumpe und Tagebuchseite")
	# Karawane
	wl._spawn_caravan(e.hero.pos2())
	T._check(wl.caravan != null and wl.car_path.size() >= 8, "Karawane fährt im Mittelring")
	e.loot["coins"] = 2000.0
	T._check(wl.buy("tool") != "", "Werkzeug schon vorhanden: kein zweites")
	var c0: float = float(e.loot.coins)
	T._check(wl.buy("egg") == "" and WS.eggs().size() == 1 and float(e.loot.coins) < c0, "Ei bei der Karawane gekauft")
	T._check(wl.buy("fuel") == "", "Treibstoff gekauft")
	e.hero.global_position = Vector3(wl.car_p.x + 2.0, 0, wl.car_p.y)
	await T._wait(0.4)
	T._check(wl.panel_open(), "Händlerfenster neben der Karawane")
	e.hero.global_position = Vector3(wl.car_p.x + 20.0, 0, wl.car_p.y)
	await T._wait(0.3)
	T._check(not wl.panel_open(), "Händlerfenster schließt beim Weggehen")
	e.abort()
	await T._wait(0.3)


# ---------------------------------------------------------------- Begleiter
func _companions() -> void:
	_fresh()
	CD.give("esel", "admin")
	CD.set_active("esel")
	CD.add_xp(1000.0, "esel")
	var e = await _start(0)
	var comp = e.companion
	T._check(comp != null and CD.level("esel") >= DW.LURE_LEVEL, "Begleiter Stufe %d" % CD.level("esel"))
	var hp2: Vector2 = e.hero.pos2()
	var near: Array = []
	for i in 6:
		var en = e.horde.spawn(D.E_SLIME, hp2 + Vector2.from_angle(i * 1.0) * 4.0, 50.0, 0.01, 0.01)
		near.append(en)
	comp.lure_cd = 0.0
	comp.start_lure(near)
	T._check(comp.st == "lure" and e.lure_t > 0.0 and comp.lures == 1, "Köder: Begleiter lockt")
	await T._wait(DW.LURE_TIME + 1.0)
	T._check(comp.st == "follow" and e.lure_t <= 0.0, "Köder endet, Begleiter kommt zurück")
	e.abort()
	await T._wait(0.3)
	# Sammelblase in der Basis
	_fresh()
	G.main.goto_base()
	await T._wait(0.5)
	var w = G.main.world
	var c2 = w.companion
	if c2 != null and c2.key != "":
		P.add_pickup("test", "bunker", {"coins": 5}, "Test")
		w.hero.global_position = Vector3(w.bunker_node.mid.x + 6.0, 0, w.bunker_node.mid.y + 6.0)
		c2.fetch_on = true
		c2._fetch_t = 0.0
		var t0 := 0
		while c2.fetches == 0 and t0 < 30:
			await T._wait(0.5)
			t0 += 1
		T._check(c2.fetches >= 1, "Begleiter holt eine Sammelblase (%d)" % c2.fetches)
		c2.fetch_on = false
	else:
		T._check(false, "Begleiter in der Basis")
	# animierte Vorschau
	var pose: Node3D = CompanionPose.new().setup("husky")
	G.main.add_child(pose)
	for i in 20:
		await T._wait(0.5)
		if pose.frames > 4:
			break
	var leg: Node3D = pose.legs[0][0] if pose.legs.size() > 0 else null
	T._check(pose.frames > 2 and leg != null and absf(leg.rotation.x) > 0.001, "Vorschau bewegt sich (%d Bilder)" % pose.frames)
	pose.queue_free()


# ---------------------------------------------------------------- Bewohner
func _npcs() -> void:
	P.debug_setup(6)
	var c := int(D.GRID_MAX / 2)
	for key in ["saege", "quartier"]:
		if P.count(key) < P.max_count(key):
			for dy in range(-12, 13, 3):
				var s0 := P.size_of(key, 0)
				if P.cells_free(c + 8, c + dy, s0.x, s0.y):
					P._add_building(key, c + 8, c + dy, 0, 1)
					break
	P.buildings_changed.emit()
	G.main.goto_base()
	await T._wait(0.8)
	var w = G.main.world
	var nb = w.npc_board
	T._check(nb != null and w.nature != null, "Basis mit Bewohnern")
	# Holzfäller fällt einen echten Baum
	var lj = null
	for n in nb.npcs:
		if n.job == "holz":
			lj = n
	var trees0: int = w.nature.felled.size()
	if lj != null:
		var s = nb._node_of("saege")
		var steps: Array = nb._tree_steps(lj, s, nb._spot(s, "drop"))
		T._check(not steps.is_empty() and steps[0].has("tree"), "Holzfäller sucht einen Baum")
		if not steps.is_empty():
			lj.give({"kind": "work", "sid": int(s.b.id), "steps": steps})
			var t0 := 0
			while nb.trees_felled == 0 and t0 < 60:
				await T._wait(1.0)
				t0 += 1
			T._check(nb.trees_felled >= 1 and w.nature.felled.size() > trees0, "Baum gefällt (%d s)" % t0)
			for key in w.nature.felled:
				w.nature.felled[key].t = w.time - DW.NPC_TREE_REGROW - 1.0
			w.nature._regrow()
			T._check(w.nature.felled.is_empty(), "Baum wächst nach")
	else:
		T._check(false, "Holzfäller vorhanden")
	# Tagesablauf: Mittag am Lagerfeuer, Abend Laternen
	NpcBoard.force_phase = "mittag"
	nb._update_phase()
	T._check(nb._fire != null, "Mittag: Lagerfeuer brennt")
	var lunch := 0
	for n in nb.npcs:
		var rt: Dictionary = nb._routine_task(n)
		if String(rt.get("steps", [{}])[0].get("clip", "")) == "warm_hands":
			lunch += 1
	T._check(lunch >= 1, "Mittagspause am Feuer (%d)" % lunch)
	NpcBoard.force_phase = "abend"
	nb._update_phase()
	T._check(nb._fire == null, "Feuer aus am Abend")
	var lamp := {}
	if w.nature.lamp_spots.size() > 0:
		for n in nb.npcs:
			if n.hero_key == "" and n.job != "wache":
				n.routine = ""
				lamp = nb._routine_task(n)
				if not lamp.is_empty():
					n.give(lamp)
					break
		T._check(not lamp.is_empty() and lamp.steps[0].has("lamp"), "Abend: Laternen anzünden")
	NpcBoard.force_phase = ""
	# Wunsch: Besuch
	var wn = null
	for n in nb.npcs:
		if n.hero_key == "" and not n.hidden:
			wn = n
			break
	var pk0: int = P.d.pickups.size()
	nb.give_wish(wn, DW.NPC_WISHES[2])
	T._check(not wn.wish.is_empty(), "Bewohner äußert einen Wunsch")
	for i in 6:
		w.hero.global_position = Vector3(wn.pos.x + 1.0, 0, wn.pos.y)
		await T._wait(0.4)
		if nb.wishes_done > 0:
			break
	T._check(nb.wishes_done == 1 and wn.wish.is_empty() and P.d.pickups.size() > pk0, "Wunsch erfüllt: Dankeschön liegt bereit")
	# Jubel im Gehen hält nicht an
	var walker = null
	for n in nb.npcs:
		if n.state == "walk":
			walker = n
	if walker != null:
		walker.cheer(2.0)
		T._check(walker.state == "walk" and walker.cheer_t <= 0.0 and walker.cheers_walking >= 1, "Jubel unterbricht den Weg nicht")
	# eigene Clips vorhanden
	var AD = preload("res://src/anim_human_data.gd")
	for clip in ["wipe_brow", "shoo", "warm_hands", "eat"]:
		T._check(AD.CLIPS.has(clip), "Clip %s" % clip)
	# Hühner scheuchen
	if w.get("wildlife") != null and w.wildlife != null:
		var cp: Vector2 = w.wildlife.chicken_spot()
		if cp != Vector2.INF:
			T._check(w.wildlife.shoo_chickens(cp + Vector2(0.5, 0), 4.0) >= 1, "Hühner flattern weg")
	T._check(nb.logic_ms < 5.0, "Bewohner-Logik bleibt schnell (%.2f ms)" % nb.logic_ms)


# ---------------------------------------------------------------- Übungsplatz
func _training() -> void:
	_fresh()
	G.main.goto_base()
	await T._wait(0.3)
	await G.main.start_training()
	await T._wait(0.3)
	var t = G.main.world
	T._check(t.mode == "practice" and t.dummies.size() == DW.TRAIN_DUMMIES, "Übungsplatz mit %d Puppen" % t.dummies.size())
	await T._wait(5.0)
	T._check(t.hits > 0 and t.total > 0.0, "Treffer an den Puppen (%d, %.0f Schaden)" % [t.hits, t.total])
	T._check(t.dps > 0.0, "Schaden pro Sekunde wird gemessen (%.0f)" % t.dps)
	var ws: Array = t.weapons()
	T._check(ws.size() >= 3, "Waffenliste des Helden (%d)" % ws.size())
	t.try_weapon(String(ws[1]))
	T._check(t.trial == String(ws[1]) and t.hero.weapon_key == String(ws[1]) and t.hits == 0, "Probewaffe in der Hand, Messung neu")
	var alive_all := true
	for d in t.dummies:
		if d.e.st == 2:
			alive_all = false
	T._check(alive_all, "Puppen fallen nicht um")
	t._finish(false)
	await T._wait(0.6)
	T._check(G.main.world.mode == "peace", "zurück in der Basis")


# ---------------------------------------------------------------- Bildschirme
func _screens() -> void:
	var s = G.main.screens
	s.open("tagebuch", {"tab": 2})
	await T._wait(0.2)
	T._check(s.is_open() and s.screen == "tagebuch", "Bildschirm Tagebuch")
	s.close()
	WS.add_egg("test")
	s.open("begleiter", "kistenbein")
	await T._wait(0.2)
	T._check(s.is_open(), "Begleiter mit Brutnest")
	s.close()
	s.open("expedition")
	await T._wait(0.2)
	s.close()
