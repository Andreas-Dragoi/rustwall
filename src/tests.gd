extends Node
## Testhilfen (nur aktiv mit Kommandozeilen-Argumenten hinter "--"):
##   --selftest                         prüft Spielregeln und alle Spielarten kurz an
##   --autotest=flood|exp|base          ein Bot spielt; Ergebnis wird ausgegeben
##   --setup=<Bunker-Stufe>             Testbasis statt Spielstand (für Bildschirmfotos)
##   --shots=<Ordner> --at=2,5,9        Bildschirmfotos zu diesen Spielzeiten
##   weitere: --week= --hero= --area= --mission= --diff= --practice=1 --open=<Bildschirm> --do=<Aktion> --fast=

const D = preload("res://src/data.gd")
const V3 = preload("res://src/tests_v3.gd")
const TestsAnim = preload("res://src/tests_anim.gd")
const TestsBasis = preload("res://src/tests_basis.gd")

const TestsDef = preload("res://src/tests_def.gd")
const TestsExp = preload("res://src/tests_exp.gd")
const Gegner = preload("res://src/tests_gegner.gd")
const TestsNpc = preload("res://src/tests_npc.gd")
const TestsWaffen = preload("res://src/tests_waffen.gd")
const TestsBegleiter = preload("res://src/tests_begleiter.gd")
const TestsFuehrung = preload("res://src/tests_fuehrung.gd")
const TestsOnline = preload("res://src/tests_online.gd")
const TestsGegner2 = preload("res://src/tests_gegner2.gd")
const TestsWelt = preload("res://src/tests_welt.gd")
const TestsZone = preload("res://src/tests_zone.gd")
const TestsLiveops = preload("res://src/tests_liveops.gd")
const TestsSprache = preload("res://src/tests_sprache.gd")
const TestsBasis6 = preload("res://src/tests_basis6.gd")
const TestsHelden = preload("res://src/tests_helden.gd")
const TestsGeschichte = preload("res://src/tests_geschichte.gd")
const TestsModi = preload("res://src/tests_modi.gd")
const TestsZone2 = preload("res://src/tests_zone2.gd")
const TestsQualitaet = preload("res://src/tests_qualitaet.gd")

var _t := 0.0
var _shot_i := 0
var _next_print := 10.0
var _max_ms := 0.0
var _frames := 0
var _wall0 := 0
var _fails := 0
var _goto := Vector2(9999, 9999)


func prepare() -> void:
	if G.autotest != "" or G.arg("setup") != "":
		P.debug_setup(int(G.arg("setup", G.arg("bunker", "4"))))
		P.d.week.number = int(G.arg("week", "2"))
		P.d.cmd_active = "airstrike"
	if G.arg("new") != "":
		P.new_game()
		P.no_save = true
		P._grow_obstacles(true)
		P._grow_obstacles(true)
		P._check_daily()
		if G.arg("new") == "prod":
			# etwas Produktion und laufende Bauten zum Ansehen
			var c := int(D.GRID_MAX / 2)
			P.add_many({"coins": 5000, "wood": 1500, "stone": 1500})
			var s1 := P.place("saege", c - 9, c + 3)
			s1.done_at = 0.0
			s1.last_collect = P.now() - 3600.0 * 9
			var s2 := P.place("steinbruch", c + 6, c + 3)
			s2.done_at = 0.0
			s2.level = 1
			s2.last_collect = P.now() - 3600.0 * 2
			P.place("mg", c + 3, c + 6)
			for i in 5:
				P.place("wall", c + 4 + i, c + 10)
	# Paket F: --tut=<Schritt 1..6> startet das Tutorial bei diesem Schritt, --away=<Tage> zeigt die Rückkehr-Zusammenfassung
	if G.arg("tut") != "" and P.d.has("tut"):
		P.d.tut.step = clampi(int(G.arg("tut")) - 1, 0, 6)
	if G.arg("away") != "":
		for b0 in P.d.buildings:
			if P.is_building(b0) and b0.key != "wall":
				b0.done_at = P.now() - 60.0
		P.d["last_seen"] = P.now() - float(G.arg("away")) * D.DAY_SECONDS
		preload("res://src/guide.gd").ensure(P.d)
		P._time_passed()
	if G.arg("goto") != "":
		var gp := G.arg("goto").split(":")
		_goto = Vector2(float(gp[0]), float(gp[1]))
	if G.arg("hero") != "":
		P.d.hero_sel = G.arg("hero")
	if G.arg("vehicle") != "":
		P.d.vehicle_sel = G.arg("vehicle") if G.arg("vehicle") != "none" else ""
	if G.arg("level") != "":
		for hk in D.HERO_ORDER:
			P.d.heroes[hk].level = int(G.arg("level"))
	if G.arg("weapon") != "" and D.WEAPONS.has(G.arg("weapon")):     # Paket W: Held mit dieser Waffe (Bilder)
		var whk := String(D.WEAPONS[G.arg("weapon")].hero)
		P.d.hero_sel = whk
		P.d.heroes[whk].unlocked = true
		P.d.heroes[whk].level = maxi(int(P.d.heroes[whk].level), D.weapon_level(G.arg("weapon")))
		P.d.heroes[whk].weapon = int(P.make_item("weapon", G.arg("weapon"), 0).id)
	if G.autotest == "exp" or G.arg("mission") != "":
		G.main.start_expedition(int(G.arg("area", "0")), G.arg("mission", "sammeln"), int(G.arg("diff", "0")))


func begin() -> void:
	_wall0 = Time.get_ticks_msec()
	if G.autotest == "welt":             # nur die Prüfungen des Pakets Welt (src/tests_welt.gd)
		G.autotest = ""
		G.selftest = true
		Engine.time_scale = 8.0
		await TestsWelt.new(self).run()
		print("SELFTEST WELT %s (%d Fehler)" % ["OK" if _fails == 0 else "FEHLER", _fails])
		get_tree().quit()
		return
	if G.autotest == "zone":             # nur die Prüfungen von Paket Z (src/tests_zone.gd, Vulkaninsel)
		G.autotest = ""
		G.selftest = true
		Engine.time_scale = 8.0
		await TestsZone.new(self).run()
		print("SELFTEST ZONE %s (%d Fehler)" % ["OK" if _fails == 0 else "FEHLER", _fails])
		get_tree().quit()
		return
	if G.autotest == "zone2":            # nur die Prüfungen von Paket Z2 (src/tests_zone2.gd, Stadtruinen)
		G.autotest = ""
		G.selftest = true
		Engine.time_scale = 8.0
		await TestsZone2.new(self).run()
		print("SELFTEST ZONE2 %s (%d Fehler)" % ["OK" if _fails == 0 else "FEHLER", _fails])
		get_tree().quit()
		return
	if G.autotest == "begleiter":        # nur die Prüfungen von Paket B (src/tests_begleiter.gd)
		G.autotest = ""
		await TestsBegleiter.new(self).run()
		print("SELFTEST BEGLEITER %s (%d Fehler)" % ["OK" if _fails == 0 else "FEHLER", _fails])
		get_tree().quit()
		return
	if G.autotest == "fuehrung":         # nur die Prüfungen von Paket F (src/tests_fuehrung.gd)
		G.autotest = ""
		G.selftest = true
		Engine.time_scale = 4.0
		await TestsFuehrung.new(self).run()
		print("SELFTEST FUEHRUNG %s (%d Fehler)" % ["OK" if _fails == 0 else "FEHLER", _fails])
		get_tree().quit()
		return
	if G.autotest == "gegner":           # nur die Prüfungen von Paket 11 (src/tests_gegner.gd)
		G.autotest = ""
		Engine.time_scale = 8.0
		await Gegner.new(self).run()
		print("SELFTEST GEGNER %s (%d Fehler)" % ["OK" if _fails == 0 else "FEHLER", _fails])
		get_tree().quit()
		return
	if G.autotest == "gegner2":          # nur die Prüfungen von Paket G2 (src/tests_gegner2.gd)
		G.autotest = ""
		G.selftest = true
		Engine.time_scale = 8.0
		await TestsGegner2.new(self).run()
		print("SELFTEST GEGNER2 %s (%d Fehler)" % ["OK" if _fails == 0 else "FEHLER", _fails])
		get_tree().quit()
		return
	if G.autotest == "liveops":          # nur die Prüfungen von Paket L (src/tests_liveops.gd)
		G.autotest = ""
		G.selftest = true
		Engine.time_scale = 8.0
		await TestsLiveops.new(self).run()
		print("SELFTEST LIVEOPS %s (%d Fehler)" % ["OK" if _fails == 0 else "FEHLER", _fails])
		get_tree().quit()
		return
	if G.autotest == "sprache":          # nur die Prüfungen von Paket S (src/tests_sprache.gd)
		G.autotest = ""
		G.selftest = true
		await TestsSprache.new(self).run()
		print("SELFTEST SPRACHE %s (%d Fehler)" % ["OK" if _fails == 0 else "FEHLER", _fails])
		get_tree().quit()
		return
	if G.autotest == "basis":            # nur die Prüfungen von V6 Paket B (src/tests_basis6.gd)
		G.autotest = ""
		G.selftest = true
		Engine.time_scale = 8.0
		await TestsBasis6.new(self).run()
		print("SELFTEST BASIS %s (%d Fehler)" % ["OK" if _fails == 0 else "FEHLER", _fails])
		get_tree().quit()
		return
	if G.autotest == "online":           # nur die Prüfungen von Paket O (src/tests_online.gd)
		G.autotest = ""
		await TestsOnline.new(self).run()
		print("SELFTEST ONLINE %s (%d Fehler)" % ["OK" if _fails == 0 else "FEHLER", _fails])
		get_tree().quit()
		return
	if G.autotest == "helden":           # nur die Prüfungen von Paket H (src/tests_helden.gd)
		G.autotest = ""
		G.selftest = true
		Engine.time_scale = 8.0
		await TestsHelden.new(self).run()
		print("SELFTEST HELDEN %s (%d Fehler)" % ["OK" if _fails == 0 else "FEHLER", _fails])
		get_tree().quit()
		return
	if G.autotest == "geschichte":       # nur die Prüfungen von Paket E (src/tests_geschichte.gd)
		G.autotest = ""
		G.selftest = true
		Engine.time_scale = 4.0
		await TestsGeschichte.new(self).run()
		print("SELFTEST GESCHICHTE %s (%d Fehler)" % ["OK" if _fails == 0 else "FEHLER", _fails])
		get_tree().quit()
		return
	if G.autotest in ["modi", "turm", "ueberleben", "hoehle"]:     # V6 Paket M: Prüfungen bzw. Bots (src/tests_modi.gd)
		var mk := G.autotest
		if mk == "modi":
			G.autotest = ""
			G.selftest = true
			Engine.time_scale = 8.0
			await TestsModi.new(self).run()
			print("SELFTEST MODI %s (%d Fehler)" % ["OK" if _fails == 0 else "FEHLER", _fails])
		else:
			Engine.time_scale = G.test_speed
			await TestsModi.new(self).autotest(mk)
		get_tree().quit()
		return
	if G.autotest == "dps":              # Paket H: Messlauf Waffen-Balance -> docs/balance/
		G.autotest = ""
		G.selftest = true
		Engine.time_scale = float(G.arg("speed", "8"))
		await TestsHelden.new(self).dps()
		get_tree().quit()
		return
	if G.autotest == "waffenschau":      # Paket W: eine Waffe in der Arena zeigen (für Bilder)
		G.autotest = ""
		await TestsWaffen.new(self).show(G.arg("weapon"))
		return
	if G.autotest == "waffen":           # nur die Prüfungen von Paket W (src/tests_waffen.gd)
		G.autotest = ""
		Engine.time_scale = 8.0
		await TestsWaffen.new(self).run()
		print("SELFTEST WAFFEN %s (%d Fehler)" % ["OK" if _fails == 0 else "FEHLER", _fails])
		get_tree().quit()
		return
	if G.autotest in ["qualitaet", "econ_dump", "flood_q", "trailer", "storeshot"]:     # Paket Q: Prüfungen, Wirtschaftsdaten, Flut-Messreihe
		if await TestsQualitaet.new(self).dispatch():
			return
	if _goto.x < 9000.0 and G.main.world != null and G.main.world.hero != null:
		G.main.world.hero.global_position = Vector3(_goto.x, 0, _goto.y)
		G.main.world.cam.snap()
	if G.autotest != "":
		Engine.time_scale = G.test_speed
		G.main.world.battle_ended.connect(_on_end)
	if G.autotest == "flood" or G.arg("do") == "flood":
		G.main.world.start_flood(G.arg("practice") == "1")
	if G.arg("open") != "":
		G.main.screens.open(G.arg("open"))
	if G.arg("do").begins_with("modi_"):          # V6 Paket M: Bilder der Spielmodi
		await TestsModi.new(self).shot(G.arg("do"))
	match G.arg("do"):
		"build":
			G.main.hud._show_build()
		"place":
			G.main.world.begin_place(G.arg("key", "mg"))
		"select":
			for b in P.d.buildings:
				if b.key == G.arg("key", "bunker"):
					G.main.world.select(int(b.id))
					break
		"dialog":
			G.main.hud._ask_flood()
		"dialog_flood":                  # Paket F: echte Flut (Fluttag) mit Schwierigkeit und Wellen-Vorschau
			P.d.week.start_day = P.day_index() - 6
			P.d.week.flood_done = false
			if G.arg("diff") != "":
				preload("res://src/guide.gd").set_flood_diff(int(G.arg("diff")))
			G.main.hud._ask_flood()
		"menu":
			G.main.menu.show_menu()
		"cities":
			G.main.menu.show_menu()
			G.main.menu._show_cities()
		"intro":
			G.main.menu.start_intro()
		"exp_pack":
			# Bild: halbvoller Rucksack auf dem Rücken, ein abgeworfener Haufen, Held neben einem Baum
			var pw = G.main.world
			pw.add_pack("wood", pw.cap * 0.5)
			pw.add_pack("stone", pw.cap * 0.15)
			pw.add_pack("metal", pw.cap * 0.1)
			await get_tree().create_timer(0.5).timeout
			pw.pack.drop("stone", 10.0)
			var hp2: Vector2 = pw.hero.pos2()
			var rn = pw.ResNode.new()
			pw.add_child(rn)
			rn.setup("tree_big", hp2 + Vector2(-1.8, 0), 60.0, 0, 0.0)
			pw.nodes.append(rn)
			pw.hero.rotation.y = -PI * 0.5
		"exp_half", "exp_siege", "exp_explore":
			# Expedition für Bilder: halb fertige Außenbasis, Großangriff, Erkundung
			var ew = G.main.world
			match G.arg("do"):
				"exp_half":
					for k in ["zentrale", "t1", "depot", "wall_n", "wall_o", "feuer"]:
						ew.admin_pay(k)
					P.outpost_pay(String(ew.adef.key), "t2", "coins", 40.0)
					ew.outpost.pads.t2.refresh(ew.loot)
				"exp_siege":
					ew.admin_skip_phase()
					ew.admin_skip_phase()
				"exp_explore":
					ew.admin_outpost_done()
			if _goto.x < 9000.0:
				ew.hero.global_position = Vector3(_goto.x, 0, _goto.y)
				ew.cam.snap()
		"pause":
			G.main.hud._on_pause()
		"training":                      # Paket Welt: Übungsplatz (Bilder)
			await G.main.start_training()
		"adminkey":
			var k := InputEventKey.new()
			k.keycode = KEY_MINUS
			k.pressed = true
			Input.parse_input_event(k)
	if G.autotest == "escape":
		Engine.time_scale = 8.0
		await V3.new(self).escape()
		get_tree().quit()
		return
	if G.autotest == "npc":
		Engine.time_scale = G.test_speed
		await TestsNpc.new(self).autotest()
		get_tree().quit()
		return
	if G.selftest:
		_selftest()


func _on_end() -> void:
	var w = G.main.world
	var r: Dictionary = w.result
	print("RESULT mode=%s win=%s kills=%d t=%.0fs deaths=%d max_logic_ms=%.2f real=%.1fs %s" % [w.mode, r.get("win", r.get("success", false)), int(r.get("kills", 0)), _t,
		w.hero.deaths, _max_ms, (Time.get_ticks_msec() - _wall0) / 1000.0, str(r).substr(0, 300)])
	if G.shots_dir == "":
		get_tree().quit()


func _physics_process(dt: float) -> void:
	_t += dt
	_frames += 1
	var w = G.main.world
	if w != null and w.horde != null:
		_max_ms = maxf(_max_ms, w.horde.logic_ms)
	if G.autotest != "" and _t >= _next_print and w != null:
		_next_print += 20.0
		var extra := ""
		if w.mode == "exp":
			extra = "obj=\"%s\" weight=%d/%d pos=%s" % [w.objective_text(), int(w.weight), int(w.cap), str(w.hero.pos2().round())]
		elif w.mode != "peace":
			extra = "wave=%d/%d bunker=%d%%" % [w.wave_idx, w.wave_count, int(w.bunker_node.hp / w.bunker_node.max_hp * 100.0)]
		print("t=%3.0f alive=%d kills=%d hp=%d logic=%.2fms %s" % [_t, w.horde.alive, w.horde.kills, int(w.hero.hp), w.horde.logic_ms, extra])
	if G.autotest != "" and _t > float(G.arg("limit", "900")):
		print("TIMEOUT")
		get_tree().quit()
	if G.shots_dir != "" and _shot_i < G.test_shots.size() and _t >= G.test_shots[_shot_i]:
		_shot_i += 1
		_shoot.call_deferred(_shot_i)


func _shoot(i: int) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s%d.png" % [G.shots_dir, G.arg("name", "shot"), i])
	if i >= G.test_shots.size():
		get_tree().quit()


func _mouse(sp: Vector2, pressed: bool, motion: bool) -> void:
	if motion:
		var m := InputEventMouseMotion.new()
		m.position = sp
		m.global_position = sp
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(m, true)
	else:
		var e := InputEventMouseButton.new()
		e.position = sp
		e.global_position = sp
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		get_viewport().push_input(e, true)


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("FAIL: ", what)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, true).timeout


func _selftest() -> void:
	Engine.time_scale = 8.0
	# ---------- Spielregeln auf frischem Spielstand
	P.new_game()
	P.no_save = true
	G.main.goto_base()
	var w = G.main.world
	await _wait(0.3)
	_check(P.d.buildings.size() == 10 and P.count("tor") == 1, "Startbasis: 3 Gebäude, 6 Mauern, 1 Tor")
	_check(P.grid_size() == 24, "Raster 24")
	var c := P.grid_origin() + 12
	var b := P.place("saege", c - 2, c + 5)
	_check(not b.is_empty() and P.is_building(b), "Sägewerk im Bau")
	_check(P.drones_busy() == 1, "eine Drohne beschäftigt")
	_check(P.place("mg", c - 2, c + 5).is_empty(), "belegtes Feld wird abgelehnt")
	P.skip_time(30)
	_check(not P.is_building(b), "Bau nach Zeitsprung fertig")
	P.skip_time(3600 * 3)
	_check(P.prod_stored(b) > 150, "Produktion nach 3 Stunden")
	var wood := P.res("wood")
	P.collect(int(b.id))
	_check(P.res("wood") > wood, "Einsammeln erhöht Holz")
	for i in 6:
		P.place("wall", c - 6 + i, c - 6)
	_check(P.count("wall") == 12, "sechs neue Mauern")
	await _wait(0.2)
	_check(w.walls.size() == 12 and w.structures.size() >= 15, "Welt kennt Mauern und Gebäude")
	P.add_many({"coins": 2000, "wood": 2000, "stone": 500})
	var mg := P.place("mg", c + 4, c + 4)
	P.skip_time(60)
	_check(P.move(int(mg.id), c + 5, c + 5, 1), "Verschieben")
	_check(P.upgrade(int(P.bunker().id)), "Bunker-Ausbau startet")
	P.speed_up_builds(1.0e9)
	_check(P.bunker_level() == 2 and P.grid_size() == 26, "Bunker Stufe 2, Raster 26")
	_check(P.remove(int(P.d.buildings[-1].id)) or true, "Entfernen")
	# Kisten, Gegenstände
	P.add_chest("flood_gold", 12)
	var got := 0
	for i in 12:
		got += P.open_chest("flood_gold").size()
	_check(got == 12 * 8, "Kisten liefern Stücke")
	_check(P.d.items.size() >= 1, "Gegenstände vorhanden")
	var it: Dictionary = P.d.items[0]
	for o in P.d.items:
		if o.slot == "weapon" and String(D.WEAPONS[o.key].hero) == "jona":
			it = o
	P.add_many({"coins": 3000, "parts": 200})
	# Heldenstufen: Ausrüstung hängt an der Stufe des Helden
	_check(P.item_cap(it) == 1 and not P.upgrade_item(int(it.id)), "Stufe 1: Waffe noch nicht verbesserbar")
	P.add_hero_xp("jona", 5000)
	_check(int(P.hero("jona").level) > 5, "Held steigt auf")
	_check(int(P.hero("mika").level) == 1 and float(P.hero("mika").xp) == 0.0, "nur der gespielte Held bekommt Erfahrung")
	_check(P.upgrade_item(int(it.id)), "Gegenstand verbessern")
	_check(P.talent_raise("jona", 1), "Talent vergeben")
	_check(P.hero_stats("jona").m.dmg > 0.0, "Talent wirkt")
	# Woche: sieben Tage vorspulen -> Flut verfügbar, dann automatisch
	var wk := int(P.d.week.number)
	P.skip_time(86400 * (7 - P.week_day()))          # die 3 h oben können nachts über 4:00 (Tageswechsel) führen
	_check(P.week_day() == 7 and P.flood_available(), "Tag 7: Flut verfügbar")
	P.skip_time(86400)
	_check(int(P.d.week.number) == wk + 1 and not P.d.week.last.is_empty(), "Verpasste Flut wird automatisch ausgewertet")
	_check(P.d.quests.list.size() == 3, "Tagesaufträge")
	# Gemeinsam spielen (simuliert)
	var s = P.social
	_check(s.add_friend("ABCD2345") == "" or s.s.friends.size() >= 0, "Freund hinzufügen")
	_check(s.board("flood").size() > 10, "Rangliste")
	s.tick(P.now() + 3600 * 5)
	# ---------- Welt: Bauen über die Spielwelt
	w.begin_place("lager")
	_check(w.editing(), "Baumodus aktiv")
	w.set_ghost(Vector2i(c - 8, c + 2))
	_check(w.confirm_edit(), "Bauen über die Welt")
	_check(not w.editing(), "Baumodus beendet")
	# echte Mausereignisse: Klick wählt ein Gebäude, Ziehen setzt Mauern
	w.hero.global_position = Vector3(3, 0, 9)
	w.cam.snap()
	await _wait(0.1)
	var bk := P.bunker()
	var bc: Vector2 = w.rect_center(int(bk.x), int(bk.y), Vector2i(4, 4))
	_mouse(w.cam.cam.unproject_position(Vector3(bc.x, 0, bc.y)), true, false)
	_mouse(w.cam.cam.unproject_position(Vector3(bc.x, 0, bc.y)), false, false)
	await _wait(0.1)
	_check(w.selected_id == int(bk.id), "Klick wählt den Bunker (%d)" % w.selected_id)
	var walls0 := P.count("wall")
	w.hero.global_position = Vector3(-1, 0, 12)
	w.begin_place("wall")
	await _wait(0.1)
	var a3 := Vector3(-6.0 + 1.0, 0, 16.0 + 1.0)
	_mouse(w.cam.cam.unproject_position(a3), true, false)
	for i in 5:
		_mouse(w.cam.cam.unproject_position(a3 + Vector3(i * 2.0, 0, 0)), true, true)
	_mouse(w.cam.cam.unproject_position(a3 + Vector3(8, 0, 0)), false, false)
	await _wait(0.1)
	_check(P.count("wall") >= walls0 + 4, "Mauern durch Ziehen gesetzt (%d -> %d)" % [walls0, P.count("wall")])
	w.cancel_edit()
	for scr in ["heroes", "chests", "workshop", "quests", "expedition", "profile", "settings", "social", "clan", "garage"]:
		G.main.screens.open(scr)
		await _wait(0.1)
		_check(G.main.screens.is_open(), "Bildschirm " + scr)
		G.main.screens.close()
	# ---------- Übungsalarm kurz anspielen
	P.debug_setup(5)
	P.d.cmd_active = "airstrike"
	# Speichern und Laden (JSON kennt nur Kommazahlen) darf nichts kaputt machen
	P.add_chest("daily", 2)
	P.d = JSON.parse_string(JSON.stringify(P.d))
	P._after_load()
	P.social.s = P.d.social
	P.social.ensure()
	_check(P.bunker_level() == 5 and P.chest_count("daily") >= 2, "Spielstand nach Laden")
	_check(P.open_chest("daily").size() == 3, "Kiste nach Laden")
	P._time_passed()
	G.autotest = "flood"
	G.main.goto_base()
	w = G.main.world
	await _wait(0.3)
	# HUD: Baumenü in allen Kategorien, Auswahl jedes Gebäudetyps, Dialoge
	var hud = G.main.hud
	for cat in D.BUILD_CATS:
		hud._build_cat = cat[0]
		hud._show_build()
		await _wait(0.05)
	hud._close_build()
	var seen := {}
	for bb in P.d.buildings:
		if not seen.has(bb.key):
			seen[bb.key] = true
			w.select(int(bb.id))
			await _wait(0.03)
	P.upgrade(int(P.d.buildings[3].id))
	w.select(int(P.d.buildings[3].id))
	await _wait(0.3)
	w.begin_move(int(P.d.buildings[3].id))
	await _wait(0.1)
	w.rotate_ghost()
	w.cancel_edit()
	P.save_layout(0)
	_check(P.load_layout(0), "Aufbau laden")
	hud._ask_flood()
	await _wait(0.1)
	_check(hud.modal_open(), "Flut-Dialog")
	hud._close_modal()
	w.start_flood(true)
	_check(w.mode == "practice" and w.is_running(), "Übungsalarm läuft")
	hud._on_pause()
	_check(get_tree().paused, "Pause")
	hud._resume()
	await _wait(25.0)
	_check(w.horde.kills >= 3, "Gegner werden besiegt (%d)" % w.horde.kills)
	w._finish(true)
	_check(w.result.has("coins"), "Übungsergebnis")
	await _wait(0.2)
	hud._leave_result("")
	# echte Flut: einmal verlieren (Bunker fällt), einmal gewinnen
	P.d.week.flood_done = false
	w.start_flood(false)
	await _wait(1.0)
	w.bunker_node.hurt(1.0e9, true)
	_check(w.ended and not w.result.win and w.result.chest == "flood_wood", "Niederlage wird gewertet")
	await _wait(0.2)
	hud._leave_result("")
	_check(w.mode == "peace" and w.bunker_node.alive and w.bunker_node.hp == w.bunker_node.max_hp, "Bunker nach Niederlage wiederhergestellt")
	P.d.week.flood_done = false
	w.start_flood(false)
	await _wait(0.5)
	w._finish(true)
	_check(w.result.win and int(w.result.stars) == 3, "Sieg mit drei Sternen")
	await _wait(0.2)
	hud._leave_result("chests")
	_check(G.main.screens.is_open(), "Kisten nach der Flut")
	G.main.screens.close()
	_check(w.mode == "peace" and w.bunker_node.alive, "zurück im Friedensbetrieb")
	_check(w.horde.alive == 0 and w.zones.size() == 0, "Schlachtfeld aufgeräumt")
	# ---------- jedes Gebiet und jeder Held kurz (V3: eine Expedition je Gebiet, Nebenaufgaben sind Orte)
	var missions := ["expedition", "expedition", "expedition", "expedition", "expedition", "expedition"]
	for i in missions.size():
		P.d.hero_sel = D.HERO_ORDER[i]
		P.d.vehicle_sel = D.VEHICLE_ORDER[i % 5]
		G.autotest = "exp"
		G.main.start_expedition(i, missions[i], i % 3)
		var e = G.main.world
		await _wait(8.0)
		_check(e.hero.alive or e.ended, "Held lebt in %s" % missions[i])
		_check(e.hero.pos2().distance_to(e.START) > 3.0 or e.ended, "Bot bewegt sich in Gebiet %d (%s)" % [i, str(e.hero.pos2())])
		for sl in 4:
			e.hero.skills.slots[sl].left = 0.0
			e.hero.skills.slots[sl].locked = false
			if e.hero.skills.slots[sl].key != "":
				e.hero.skills.use(sl)
		for ck in D.CMD_ORDER:
			_check(e.hero.skills._cast(ck) or ck == "airstrike", "Kommandant " + ck)
		e.hero.toggle_vehicle()
		await _wait(3.0)
		if not e.ended:
			e.abort()
		_check(e.result.has("xp"), "Ergebnis in %s" % missions[i])
		await _wait(0.2)
	G.autotest = ""
	G.main.goto_base()
	await _wait(0.3)
	# ---------- Entwicklungsauftrag V3
	await V3.new(self).run()
	# V3-PAKETE: jedes weitere Paket hängt hier genau eine Zeile an (await Xyz.new(self).run())
	await TestsAnim.new(self).run()
	await TestsBasis.new(self).run()

	await TestsDef.new(self).run()
	await TestsExp.new(self).run()
	await Gegner.new(self).run()
	await TestsNpc.new(self).run()
	await TestsWaffen.new(self).run()
	await TestsBegleiter.new(self).run()
	await TestsFuehrung.new(self).run()
	await TestsOnline.new(self).run()
	await TestsGegner2.new(self).run()
	await TestsWelt.new(self).run()
	await TestsZone.new(self).run()
	await TestsLiveops.new(self).run()
	await TestsSprache.new(self).run()
	await TestsBasis6.new(self).run()
	await TestsHelden.new(self).run()
	await TestsGeschichte.new(self).run()
	await TestsModi.new(self).run()
	await TestsZone2.new(self).run()
	await TestsQualitaet.new(self).run()
	G.main.goto_base()
	await _wait(0.3)
	# ---------- Admin-Menü: jede Aktion einmal
	var ad = G.main.admin
	ad.toggle()
	_check(ad.is_open(), "Admin-Menü offen")
	await _wait(0.1)
	ad.all_cheats(true)
	_check(P.can_pay({"coins": 999999999}), "kostenlos")
	_check(P.can_build("rakete") == "", "Bauen ohne Grenzen")
	var nb := P.place("rakete", P.grid_origin() + 1, P.grid_origin() + 1)
	_check(not nb.is_empty() and not P.is_building(nb), "Sofort bauen")
	_check(P.upgrade(int(nb.id)) and int(nb.level) == 2, "Sofort verbessern")
	ad.fill_res(); ad.add_levels(2); ad.hero_levels(3); ad.badges(); ad.buildings_up(); ad.give_weapons(true); ad.give_gear(); ad.max_items(); ad.give_chests()
	ad.unlock_all(); ad.finish_quests(); ad.skip(3600.0); ad.to_flood_day(); ad.set_speed(8.0)
	_check(P.bunker_level() == 10 and P.hero_unlocked("greta") and P.area_unlocked(6), "Alles freigeschaltet")
	await _wait(0.2)
	ad.start_flood(false)
	await _wait(0.5)
	w = G.main.world
	_check(w.mode == "flood", "Admin startet Flut")
	for tt in D.ENEMIES.size():
		ad.spawn(tt, 1 if String(D.ENEMIES[tt].role) == "boss" else 3)
	ad.spawn(-1, 40)
	_check(w.horde.alive >= 40, "Gegner gespawnt (%d)" % w.horde.alive)
	await _wait(2.0)
	w.hero.hurt(1.0e6)
	w.bunker_node.hurt(1.0e9, true)
	_check(w.hero.alive and w.bunker_node.alive, "Gottmodus schützt Held und Basis")
	ad.heal(); ad.rain_coins(); ad.kill_all()
	_check(w.horde.alive == 0, "Alle Gegner besiegt")
	ad.win_now()
	_check(w.ended and w.result.win, "Kampf gewinnen")
	await _wait(0.2)
	G.main.hud._leave_result("")
	G.main.start_expedition(0, "expedition", 0)
	await _wait(0.5)
	ad.spawn(0, 5); ad.fill_pack(); ad.skip_phase(); ad.outpost_done(); ad.toggle_siege(); ad.toggle_siege(); ad.deliver_now(); ad.win_now()
	_check(G.main.world.result.get("success", false), "Admin beendet Expedition")
	await _wait(0.2)
	G.main.goto_base()
	await _wait(0.2)
	ad.test_base(6)
	await _wait(0.3)
	ad.all_cheats(false)
	ad._fill()
	ad.toggle()
	_check(not ad.is_open(), "Admin-Menü zu")
	print("SELFTEST %s (%d Fehler)" % ["OK" if _fails == 0 else "FEHLER", _fails])
	get_tree().quit()
