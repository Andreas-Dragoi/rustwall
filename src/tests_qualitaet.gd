extends RefCounted
## Paket Q (Qualität): Prüfungen und Messläufe.
##
## Aufruf aus tests.gd (--selftest) oder allein:
##   --autotest=qualitaet                    alle Prüfungen von Paket Q
##   --autotest=econ_dump [--out=<datei>]    alle Zahlen der Wirtschaft als JSON (für tools/wirtschaft_sim.py)
##   --autotest=storeshot --motif=basis|flut|expedition|vulkan|angriff|boss|helden --out=<png>   Bild für den Store (mit Fenster)
##   --autotest=trailer --setup=8 --week=8 Vorschau-Video (mit --write-movie aufnehmen, siehe tools/store_material.py)
##   --autotest=flood_q --bunker=5 --week=6 --tower=4 --herolv=12 --wall=2 [--plevel=20]
##                                           Flut-Bot auf einer „normal ausgebauten“ Basis (Werte aus der Simulation)
##                                           --passive=1: Held bleibt am Bunker (vorsichtiger Spieler)

const D = preload("res://src/data.gd")
const DB = preload("res://src/data_basis.gd")
const DL = preload("res://src/data_liveops.gd")
const DF = preload("res://src/data_fuehrung.gd")
const Research = preload("res://src/research.gd")
const Dev = preload("res://src/device_cfg.gd")
const Guide = preload("res://src/guide.gd")
const AutoQ = preload("res://src/auto_quality.gd")
const Pc = preload("res://src/pc_input.gd")
const A11y = preload("res://src/a11y.gd")
const Captions = preload("res://src/captions.gd")
const ScreenFit = preload("res://src/screen_fit.gd")

var T: Node


func _init(tests: Node) -> void:
	T = tests


## Verteiler für die eigenen Autotests. Rückgabe true: fertig (Spiel beendet), false: normaler Ablauf geht weiter.
func dispatch() -> bool:
	match G.autotest:
		"econ_dump":
			G.autotest = ""
			G.selftest = true
			econ_dump(G.arg("out", "res://docs/balance/wirtschaft_daten.json"))
			T.get_tree().quit()
			return true
		"qualitaet":
			G.autotest = ""
			G.selftest = true
			Engine.time_scale = 8.0
			await run()
			print("SELFTEST QUALITAET %s (%d Fehler)" % ["OK" if T._fails == 0 else "FEHLER", T._fails])
			T.get_tree().quit()
			return true
		"storeshot":
			await store_shot(G.arg("motif", "basis"), G.arg("out", "user://store.png"))
			T.get_tree().quit()
			return true
		"trailer":
			await trailer()
			T.get_tree().quit()
			return true
		"flood_q":
			flood_setup(int(G.arg("bunker", "4")), int(G.arg("week", "2")), int(G.arg("tower", "3")), int(G.arg("herolv", "10")),
				int(G.arg("wall", "1")), int(G.arg("plevel", "0")))
			G.autotest = "flood"                  # ab hier spielt der normale Flut-Bot
			await G.main.goto_base()
			await T._wait(0.2)
			if G.arg("passive") == "1":
				# vorsichtiger Spieler: der Held bleibt am Bunker stehen und schießt nur, was in Reichweite kommt
				G.main.world.hero.test_wish = Vector2.ZERO
			return false
	return false


# ================================================================= Prüfungen
func run() -> void:
	Dev.reset_mem()
	_economy()
	await _auto_quality()
	await _keys()
	await _a11y()
	await _captions()
	await _pad_game()
	await _pad_menus()
	await _settings_screen()
	_i18n()
	Dev.reset_mem()
	A11y.apply(G.main)
	_fresh()
	G.main.goto_base()
	await T._wait(0.3)


func _fresh() -> void:
	P.new_game()
	P.no_save = true
	P._ensure_fields()


func _base() -> Node:
	if G.main.world == null or String(G.main.world.mode) != "peace" or not G.main.world.has_method("begin_place"):
		G.main.goto_base()
		await T._wait(0.3)
	return G.main.world


func _joy_button(b: JoyButton, pressed: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = pressed
	e.pressure = 1.0 if pressed else 0.0
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _joy_axis(ax: JoyAxis, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = ax
	e.axis_value = v
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _tap_joy(b: JoyButton) -> void:
	_joy_button(b, true)
	await T._wait(0.05)
	_joy_button(b, false)
	await T._wait(0.05)


func _key(k: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.keycode = k
	e.pressed = pressed
	Input.parse_input_event(e)
	Input.flush_buffered_events()


# ---------------------------------------------------------------- Wirtschaft: Bunker 10 bezahlbar, Vorschau mit Forschung
func _economy() -> void:
	_fresh()
	# größtes mögliches Lager bei Bunker 9 (vier Lager auf Stufe 9), ohne Forschung
	var bk := P.bunker()
	bk.level = 9
	for i in 4:
		var l := P._add_building("lager", 2 + i * 3, 2, 0, 9)
		l.done_at = 0.0
	var c10 := D.bunker_cost(10)
	var ok := true
	for r in c10:
		if r != "coins" and int(c10[r]) > P.cap(r):
			ok = false
	T._check(ok, "Q: Bunker 10 passt ins Lager (Holz %d ≤ %d)" % [int(c10.wood), P.cap("wood")])
	T._check(int(D.bunker_cost(7).wood) == 9190 and int(D.bunker_cost(8).wood) < int(round(400.0 * pow(2.15, 6) * 0.5)), "Q: Bunker bis 7 unverändert, ab 8 weniger Holz")
	# Vorschau beim Stufenaufstieg rechnet Forschung und Schmuck mit (wie P.prod_rate)
	_fresh()
	var sg := P._add_building("saege", 4, 4, 0, 1)
	sg.done_at = 0.0
	var before: String = Guide.upgrade_preview("saege", 1)[0][2]
	P.d.research.done = ["w_lager", "w_saegen"]
	var after: Array = Guide.upgrade_preview("saege", 1)[0]
	T._check(String(after[2]) == "+%d" % int(P.prod_rate(sg)) and String(after[2]) != before, "Q: Vorschau Produktion mit Forschung (%s → %s)" % [before, after[2]])
	var mg: Array = Guide.upgrade_preview("mg", 1)[0]
	P.d.research.done = ["t_optik", "t_lader"]
	var mg2: Array = Guide.upgrade_preview("mg", 1)[0]
	T._check(int(String(mg2[2])) > int(String(mg[2])), "Q: Vorschau Turmschaden mit Forschung (%s → %s)" % [mg[2], mg2[2]])
	P.d.research.done = []


# ---------------------------------------------------------------- Grafikstufe automatisch
func _auto_quality() -> void:
	T._check(AutoQ.choose(60.0, true) == 2 and AutoQ.choose(40.0, true) == 1 and AutoQ.choose(20.0, true) == 0, "Q: Auto-Grafik PC: 60→Hoch, 40→Mittel, 20→Niedrig")
	T._check(AutoQ.choose(58.0, false) == 1 and AutoQ.choose(30.0, false) == 0, "Q: Auto-Grafik Handy: höchstens Mittel")
	_fresh()
	T._check(G.quality() == 1 and AutoQ.auto_quality() == -1, "Q: ohne Messung Standard „Mittel“")
	Dev.set_v("auto_q", 0)
	T._check(G.quality() == 0, "Q: gemessene Stufe gilt")
	P.d.settings["quality_user"] = true
	P.d.settings["quality"] = 2
	T._check(G.quality() == 2, "Q: eigene Wahl geht vor")
	P.d.settings["quality_user"] = false
	Dev.erase("auto_q")
	# echte Messung (einige Sekunden) in der Basis
	await _base()
	AutoQ.maybe_start(G.main, true)
	var t := 0.0
	while AutoQ.auto_quality() < 0 and t < 30.0:
		await T._wait(0.5)
		t += 0.5 / Engine.time_scale
	T._check(AutoQ.auto_quality() >= 0 and int(Dev.get_v("auto_fps", 0)) > 0, "Q: Messung beim ersten Start (%d Bilder/s → Stufe %d)" % [int(Dev.get_v("auto_fps", 0)), AutoQ.auto_quality()])
	T._check(not AutoQ.measuring, "Q: Messung beendet, Bildratenbremse wieder an")
	Dev.erase("auto_q")
	Dev.erase("auto_fps")


# ---------------------------------------------------------------- Tastenbelegung
func _keys() -> void:
	await _base()
	Pc.reset_keys()
	T._check(Pc.key_of("dodge") == KEY_SPACE and Pc.key_of("skill1") == KEY_Q, "Q: Standardtasten")
	Pc.set_key("dodge", KEY_K)
	var has_k := false
	var has_space := false
	for e in InputMap.action_get_events("dodge"):
		if e is InputEventKey:
			has_k = has_k or e.physical_keycode == KEY_K
			has_space = has_space or e.physical_keycode == KEY_SPACE
	T._check(has_k and not has_space, "Q: Ausweichen liegt jetzt auf K")
	var sw := Pc.set_key("skill1", KEY_K)
	T._check(Pc.key_of("skill1") == KEY_K and Pc.key_of("dodge") == KEY_Q and sw != "", "Q: Doppelbelegung wird getauscht (%s)" % sw)
	# simulierter Tastendruck löst die Aktion aus
	var hits := [0]
	var cb := func(slot: int):
		if slot == 0:
			hits[0] += 1
	G.skill_pressed.connect(cb)
	_key(KEY_K, true)
	await T._wait(0.05)
	_key(KEY_K, false)
	await T._wait(0.05)
	G.skill_pressed.disconnect(cb)
	T._check(hits[0] == 1, "Q: neue Taste K löst Fähigkeit 1 aus")
	# Pfeiltasten (Zweitbelegung) bleiben
	var arrows := false
	for e in InputMap.action_get_events("move_left"):
		arrows = arrows or (e is InputEventKey and e.physical_keycode == KEY_LEFT)
	T._check(arrows, "Q: Pfeiltasten bleiben")
	Pc.reset_keys()
	T._check(Pc.key_of("dodge") == KEY_SPACE and Pc.key_of("skill1") == KEY_Q, "Q: Standardbelegung wiederhergestellt")
	T._check(Pc.key_name(KEY_SPACE) == "Leertaste" and Pc.key_name(KEY_Q) != "", "Q: Tastennamen")
	# Bildratenbegrenzung (PC)
	if Pc.is_pc():
		Pc.set_fps_cap(144)
		T._check(ScreenFit.fps_target() == 144 or ScreenFit.battery_saver(), "Q: Bildratenbegrenzung 144")
		Pc.set_fps_cap(-1)


# ---------------------------------------------------------------- Barrierefreiheit
func _a11y() -> void:
	await _base()
	A11y.set_cb_mode(1)
	await T._wait(0.1)
	T._check(A11y.filter_on(), "Q: Farbfilter an (Deuteranopie)")
	var mat: ShaderMaterial = A11y._rect.material
	T._check(mat != null and mat.shader != null and int(mat.get_shader_parameter("mode")) == 1, "Q: Farbfilter-Shader gesetzt")
	A11y.set_cb_mode(3)
	T._check(int(mat.get_shader_parameter("mode")) == 3, "Q: Farbfilter Tritanopie")
	A11y.set_cb_mode(0)
	T._check(not A11y.filter_on(), "Q: Farbfilter aus")
	A11y.set_calm(true)
	G.hud.damage_flash()
	T._check(absf(float(G.hud._flash_a) - 0.09) < 0.001, "Q: Trefferblitz abgeschwächt")
	A11y.set_calm(false)
	G.hud.damage_flash()
	T._check(absf(float(G.hud._flash_a) - 0.3) < 0.001, "Q: Trefferblitz normal")


func _captions() -> void:
	await _base()
	Dev.set_v("captions", true)
	A11y.apply(G.main)
	var n0 := Captions.shown
	Sfx.play("flood_alarm", -80.0)
	T._check(Captions.shown == n0 + 1 and Captions.last_text.contains("Flut"), "Q: Untertitel Flut-Alarm (auch leise)")
	Captions._last.clear()
	var hp: Vector3 = G.main.world.hero.global_position
	Sfx.play_at("explosion_small", hp + Vector3(60, 0, 0), -6.0)
	T._check(Captions.shown == n0 + 1, "Q: ferne Explosion ohne Untertitel")
	Sfx.play_at("explosion_small", hp + Vector3(4, 0, 0), -6.0)
	T._check(Captions.shown == n0 + 2 and Captions.last_text == "Explosion", "Q: nahe Explosion mit Untertitel")
	Sfx.play("click", -6.0)
	T._check(Captions.shown == n0 + 2, "Q: unwichtige Töne ohne Untertitel")
	await T._wait(0.1)
	T._check(Captions._layer != null and Captions._box.get_child_count() >= 1, "Q: Untertitel sichtbar")
	Dev.set_v("captions", false)
	A11y.apply(G.main)
	Sfx.play("boss_arrive", -6.0)
	T._check(Captions.shown == n0 + 2, "Q: Untertitel aus")


# ---------------------------------------------------------------- Gamepad im Spiel
func _pad_game() -> void:
	var w = await _base()
	var nav = Pc.nav
	T._check(nav != null and is_instance_valid(nav), "Q: Gamepad-Navigation läuft")
	# linker Stick: Laufen
	_joy_axis(JOY_AXIS_LEFT_X, 1.0)
	await T._wait(0.05)
	var mv := G.move_vector()
	_joy_axis(JOY_AXIS_LEFT_X, 0.0)
	T._check(mv.x > 0.8, "Q: linker Stick läuft (%s)" % str(mv))
	T._check(nav.active, "Q: Gamepad als Eingabe erkannt")
	# Fähigkeit X
	var hits := [0]
	var cb := func(slot: int):
		if slot == 0:
			hits[0] += 1
	G.skill_pressed.connect(cb)
	await _tap_joy(JOY_BUTTON_X)
	G.skill_pressed.disconnect(cb)
	T._check(hits[0] == 1, "Q: X löst Fähigkeit 1 aus")
	# Select: Gebäude am Helden wählen
	var bunker_id := -1
	for id in w.nodes:
		if w.nodes[id] == w.bunker_node:
			bunker_id = int(id)
	var bn: Node3D = w.bunker_node
	w.hero.global_position = bn.global_position + Vector3(0, 0, 4.5)
	w.select(-1)
	await _tap_joy(JOY_BUTTON_BACK)
	await T._wait(0.1)
	T._check(int(w.selected_id) >= 0, "Q: Select wählt das Gebäude am Helden (%d)" % int(w.selected_id))
	await _tap_joy(JOY_BUTTON_B)
	T._check(int(w.selected_id) < 0, "Q: B schließt die Auswahl")
	# Bauen mit dem Gamepad: Baufeld folgt der Bildmitte, A setzt
	P.add_many({"coins": 5000, "wood": 3000, "stone": 2000})
	var n0 := P.count("mg")
	w.begin_place("mg")
	await T._wait(0.15)
	_joy_button(JOY_BUTTON_A, true)          # Gamepad aktiv halten
	await T._wait(0.05)
	_joy_button(JOY_BUTTON_A, false)
	await T._wait(0.05)
	T._check(P.count("mg") == n0 + 1 or not w.editing(), "Q: A setzt das Gebäude im Baumodus (%d → %d)" % [n0, P.count("mg")])
	if w.editing():
		w.cancel_edit()
	# rechter Stick zielt im Kampf
	w.start_flood(true)
	await T._wait(0.3)
	_joy_axis(JOY_AXIS_RIGHT_X, -1.0)
	await T._wait(0.15)
	var aim: Vector2 = w.hero._aim
	_joy_axis(JOY_AXIS_RIGHT_X, 0.0)
	T._check(aim.length() > 0.9, "Q: rechter Stick zielt (%s)" % str(aim))
	w._finish(true)
	G.hud._close_modal()
	w.back_to_peace()
	await T._wait(0.2)
	nav.set_active(false)


# ---------------------------------------------------------------- Gamepad in Menüs
func _pad_menus() -> void:
	await _base()
	var nav = Pc.nav
	G.main.screens.open("settings")
	await T._wait(0.1)
	await _tap_joy(JOY_BUTTON_DPAD_DOWN)
	for i in 6:
		await T.get_tree().process_frame
	var vp := G.main.get_viewport()
	var f1: Control = vp.gui_get_focus_owner()
	T._check(f1 != null and G.main.screens._root.is_ancestor_of(f1), "Q: Menü bekommt Fokus (%s)" % (f1.get_class() if f1 else "kein"))
	T._check(nav._frame.visible, "Q: Fokusrahmen sichtbar")
	var moved := false
	for i in 4:
		await _tap_joy(JOY_BUTTON_DPAD_DOWN)
		await T._wait(0.05)
		if vp.gui_get_focus_owner() != f1:
			moved = true
			break
	T._check(moved, "Q: Steuerkreuz bewegt den Fokus")
	# A drückt den fokussierten Knopf: Farbfilter-Knopf anwählen und drücken
	var cbb: Button = null
	for c in nav._all(G.main.screens._root):
		if c is Button and int(c.get_meta("cb_mode", -1)) == 2:
			cbb = c
	if cbb != null:
		cbb.grab_focus()
		await _tap_joy(JOY_BUTTON_A)
		await T._wait(0.1)
	T._check(A11y.cb_mode() == 2, "Q: A drückt den Knopf unter dem Fokus (Farbfilter %d)" % A11y.cb_mode())
	A11y.set_cb_mode(0)
	await _tap_joy(JOY_BUTTON_B)
	await T._wait(0.1)
	T._check(not G.main.screens.is_open(), "Q: B schließt das Menü")
	# Dialog (Übungsalarm) mit dem Gamepad
	G.hud._ask_flood()
	await T._wait(0.1)
	if G.hud.modal_open():
		await _tap_joy(JOY_BUTTON_DPAD_DOWN)
		await T._wait(0.15)
		var f2: Control = vp.gui_get_focus_owner()
		T._check(f2 != null and G.hud._modal.is_ancestor_of(f2), "Q: Dialog bekommt Fokus")
		await _tap_joy(JOY_BUTTON_B)
		await T._wait(0.05)
		T._check(not G.hud.modal_open(), "Q: B schließt den Dialog")
	# Maus schaltet zurück: Fokus und Rahmen weg
	var mm := InputEventMouseButton.new()
	mm.button_index = MOUSE_BUTTON_LEFT
	mm.pressed = false
	mm.position = Vector2(5, 5)
	Input.parse_input_event(mm)
	Input.flush_buffered_events()
	await T._wait(0.05)
	T._check(not nav.active and not nav._frame.visible, "Q: Maus schaltet Gamepad-Navigation ab")


# ---------------------------------------------------------------- Einstellungen: neue Tafeln
func _settings_screen() -> void:
	await _base()
	G.main.screens.open("settings")
	await T._wait(0.15)
	var nav = Pc.nav
	var root: Control = G.main.screens._root
	var cbs := 0
	var kbtn: Button = null
	for c in nav._all(root):
		if c is Button and c.has_meta("cb_mode"):
			cbs += 1
		if c is Button and String(c.get_meta("key_action", "")) == "use":
			kbtn = c
	T._check(cbs == A11y.CB_MODES.size(), "Q: Einstellungen zeigen den Farbfilter (%d)" % cbs)
	T._check(kbtn != null, "Q: Einstellungen zeigen die Tastenbelegung")
	if kbtn != null:
		kbtn.pressed.emit()
		await T._wait(0.1)
		T._check(root.get_node_or_null("QCatcher") != null, "Q: wartet auf eine Taste")
		_key(KEY_G, true)
		await T._wait(0.05)
		_key(KEY_G, false)
		await T._wait(0.1)
		T._check(Pc.key_of("use") == KEY_G, "Q: Taste im Menü umbelegt (Fahrzeug → G)")
	Pc.reset_keys()
	G.main.screens.close()
	await T._wait(0.05)


func _i18n() -> void:
	var I18N = preload("res://src/i18n.gd")
	if not I18N.is_en():
		return
	var t := TranslationServer.translate("Welle 1: Schleimling + Flitzer + 2 weitere")
	T._check(not t.contains("Schleimling") and not t.contains("weitere"), "Q: Wellen-Vorschau auf Englisch (%s)" % t)
	var p := TranslationServer.translate("%s Ranglistenpunkte" % "1.234")
	T._check(not p.contains("Ranglisten"), "Q: Ranglistenpunkte auf Englisch (%s)" % p)


# ================================================================= Messung: Flut auf „normal ausgebauter“ Basis
## Baut die Testbasis wie P.debug_setup, setzt dann alle Türme/Fallen auf Stufe tower, Mauern auf die Stufe wall,
## Helden auf Stufe herolv. So entspricht die Basis dem Stand, den die Wirtschaftssimulation für diese Woche ausgibt.
func flood_setup(bl: int, week: int, tower: int, herolv: int, wall: int, plevel: int) -> void:
	P.debug_setup(bl)
	P.d.week.number = week
	P.d.cmd_active = "airstrike"
	if plevel > 0:
		P.d.level = clampi(plevel, 1, D.MAX_LEVEL)
	for b in P.d.buildings:
		var cat := String(D.BUILDINGS[b.key].cat)
		if cat == "def" or cat == "trap":
			b.level = clampi(tower, 1, P.max_level(String(b.key)))
		elif b.key == "wall" or b.key == "tor":
			b.level = clampi(wall, 1, 3)
	for hk in D.HERO_ORDER:
		P.d.heroes[hk].level = clampi(herolv, 1, D.HERO_MAX_LEVEL)
	if G.arg("fdiff") != "":
		Guide.set_flood_diff(int(G.arg("fdiff")))       # 1 = Schwer, 2 = Albtraum
	P.buildings_changed.emit()


# ================================================================= Wirtschaftsdaten für die Simulation
## Schreibt alle für die Wirtschaft nötigen Zahlen als JSON. Formeln, die nur im Code stehen, werden als Tabellen
## über die echten Funktionen ausgerechnet (cost_for, build_time, bunker_cost, flood_def, xp_need, Forschung).
## Beutekisten: Durchschnitt aus 400 echten Öffnungen je Kistenart und Bunker-Stufe (Zufall).
func econ_dump(path: String) -> void:
	P.new_game()
	P.no_save = true
	var out := {}
	out["res"] = D.RES
	out["cap_base"] = D.CAP_BASE
	out["start_res"] = D.START_RES
	out["prod_store_hours"] = D.PROD_STORE_HOURS
	out["drones"] = D.DRONES_BY_BUNKER
	out["gem_drone_cost"] = D.GEM_DRONE_COST
	out["gem_reward"] = D.GEM_REWARD
	out["gem_curve"] = D.GEM_CURVE
	out["gem_free_seconds"] = D.GEM_FREE_SECONDS
	out["flood_loss"] = D.FLOOD_LOSS
	out["expedition_build_skip"] = D.EXPEDITION_BUILD_SKIP
	out["auto_hours"] = D.AUTO_HOURS
	out["auto_share"] = D.AUTO_SHARE
	out["res_weight"] = D.RES_WEIGHT
	out["backpack"] = D.BACKPACK
	out["max_level"] = D.MAX_LEVEL
	out["hero_max_level"] = D.HERO_MAX_LEVEL
	out["train_xp"] = [D.TRAIN_XP_PER_HOUR, D.TRAIN_XP_PER_LEVEL]
	out["deco_bonus"] = [D.DECO_BONUS_PER, D.DECO_BONUS_MAX]
	# Gebäude: Daten und Kosten/Zeit je Stufe aus den echten Funktionen
	var blds := {}
	for k in D.BUILDINGS:
		var def: Dictionary = D.BUILDINGS[k]
		var cat := String(def.cat)
		if cat == "obstacle":
			continue
		var e := {"cat": cat, "unlock": int(def.unlock), "max": def.max, "size": def.size, "hp": float(def.get("hp", 0.0)),
			"prod": String(def.get("prod", "")), "rate": float(def.get("rate", 0.0)), "deco": int(def.get("deco", D.DECO_POINTS_OLD.get(k, 0))),
			"tower": String(def.get("tower", "")), "story": String(def.get("story", "")), "cost": [], "time": []}
		for lv in range(1, 11):
			e.cost.append(P.cost_for(k, lv))
			e.time.append(D.build_time(k, lv))
		blds[k] = e
	out["buildings"] = blds
	var bc := {}
	for lv in range(2, 11):
		bc[str(lv)] = D.bunker_cost(lv)
	out["bunker_cost"] = bc
	out["bunker_hp"] = range(1, 11).map(func(l): return D.bunker_hp(l))
	out["coin_cap"] = range(1, 11).map(func(l): return int(4000.0 * pow(1.9, l - 1)))
	# Prüfwert für die Lager-Formel der Simulation: frischer Spielstand, Bunker 1, kein Lager
	out["cap_check"] = {"wood": P.cap("wood"), "coins": P.cap("coins")}
	var towers := {}
	for tk in D.TOWERS:
		var t: Dictionary = D.TOWERS[tk]
		towers[tk] = {"damage": float(t.damage), "rpm": float(t.rpm), "splash": float(t.get("splash", 0.0))}
	out["towers"] = towers
	out["tower_dmg_growth"] = D.TOWER_DMG_GROWTH
	# Flut: Stärke je Woche und Bunker, Belohnung
	var fl := []
	for w in range(1, 31):
		var row := []
		for bl in range(1, 11):
			row.append(D.flood_def(w, bl))
		fl.append(row)
	out["flood_def"] = fl
	out["flood_diffs"] = DF.FLOOD_DIFFS
	out["xp_need"] = range(1, D.MAX_LEVEL + 1).map(func(l): return D.xp_need(l))
	out["hero_xp_need"] = range(1, D.HERO_MAX_LEVEL + 1).map(func(l): return D.hero_xp_need(l))
	out["badge_gates"] = D.BADGE_GATES
	out["weekly_pool"] = DL.WEEKLY_POOL
	out["heroes"] = D.HERO_ORDER.map(func(k): return {"key": k, "unlock_area": int(D.HEROES[k].unlock_area)})
	out["areas"] = D.AREAS.map(func(a): return {"key": a.key, "name": a.name, "level": int(a.level), "fuel": int(a.fuel), "res": a.res})
	out["quests"] = D.QUESTS
	out["achievements"] = D.ACHIEVEMENTS.map(func(a): return {"key": a.key, "tiers": a.tiers, "gems": a.gems})
	out["calendar"] = DL.CALENDAR
	out["weekly"] = {"n": DL.WEEKLY_N, "reward": DL.WEEKLY_REWARD, "all": DL.WEEKLY_ALL_REWARD}
	out["boost_seconds"] = DL.BOOST_SECONDS
	out["vehicles"] = D.VEHICLES.keys().map(func(k): return {"key": k, "bunker": int(D.VEHICLES[k].bunker), "cost": D.VEHICLES[k].cost, "carry": float(D.VEHICLES[k].carry)})
	out["tut_flood_reward"] = DF.TUT_FLOOD_REWARD
	out["return_gift"] = [DF.RETURN_GIFT_PER_DAY, DF.RETURN_GIFT_MAX_DAYS]
	# Forschung
	var rs := {}
	for k in DB.NODES:
		var n: Dictionary = DB.NODES[k]
		rs[k] = {"branch": n.branch, "tier": int(n.tier), "stat": n.stat, "val": float(n.val), "req": n.req, "cost": Research.cost(k),
			"time": float(DB.TIER_COST[int(n.tier)].time), "lab": int(DB.TIER_LAB[int(n.tier)])}
	out["research"] = rs
	out["lab_speed"] = DB.LAB_SPEED
	# Beutekisten: Mittelwert der Rohstoffe je Öffnung (echter Code, 400 Öffnungen) je Bunker-Stufe 1..10
	var ch := {}
	var types: Array = D.CHESTS.keys()
	for bl in range(1, 11):
		P.new_game()
		P.no_save = true
		P.bunker().level = bl
		P.d.level = clampi(bl * 5, 1, 60)
		var row := {}
		for tp in types:
			var sum := {}
			var n := 400
			for i in n:
				for r in D.RES:
					P.d.res[r] = 0
				P.d.chests[tp] = 1
				P.open_chest(tp)
				for r in D.RES:
					if P.res(r) > 0:
						sum[r] = float(sum.get(r, 0.0)) + P.res(r)
			for r in sum:
				sum[r] = snappedf(float(sum[r]) / n, 0.1)
			row[tp] = sum
		ch[str(bl)] = row
	out["chests"] = ch
	var f := FileAccess.open(ProjectSettings.globalize_path(path) if path.begins_with("res://") else path, FileAccess.WRITE)
	if f == null:
		print("ECON_DUMP FEHLER: kann %s nicht schreiben" % path)
		return
	f.store_string(JSON.stringify(out, " ", false))
	f.close()
	print("ECON_DUMP OK %s" % path)


# ================================================================= Vorschau-Video (Store, Kapitel 7.4)
## Ablauf von etwa 26 Sekunden mit Kamerafahrt: Basis von oben umkreisen, die Flut beginnt, der Held kämpft (Bot),
## dann Expedition in die Staubebene. Aufnahme mit --write-movie (feste Bildrate), Texte setzt tools/store_material.py.
func trailer() -> void:
	Engine.time_scale = 1.0
	var w = G.main.world
	var cam = w.cam
	G.hud.visible = true
	P.d.week.start_day = P.day_index() - 6            # Fluttag
	var bpos: Vector3 = w.bunker_node.global_position
	cam.override_target = bpos
	cam.dist = 72.0
	cam.yaw_off = -0.7
	cam.snap()
	var t := 0.0
	var flood := false
	while t < 6.0:
		await T.get_tree().process_frame
		var dt: float = T.get_process_delta_time()
		t += dt
		var k := clampf(t / 6.0, 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		cam.yaw_off = lerpf(-0.7, 0.15, e)
		cam.dist = lerpf(72.0, 40.0, e)
		cam.override_target = bpos.lerp(w.hero.global_position, e)
		if t > 2.5 and not flood:
			flood = true
			w.start_flood(false)
			await T.get_tree().process_frame
			if w.has_method("skip_break"):
				w.skip_break()
	cam.override_target = null
	while t < 16.0:
		await T.get_tree().process_frame
		var dt2: float = T.get_process_delta_time()
		t += dt2
		cam.dist = lerpf(40.0, 30.0, clampf((t - 6.0) / 3.0, 0.0, 1.0))
		cam.yaw_off = lerpf(0.15, -0.1, clampf((t - 6.0) / 10.0, 0.0, 1.0))
	# Expedition
	G.main.start_expedition(2, "expedition", 0)
	await T.get_tree().process_frame
	await T.get_tree().process_frame
	var ew = G.main.world
	ew.cam.dist = 34.0
	ew.cam.yaw_off = -0.25
	while t < 26.5:
		await T.get_tree().process_frame
		var dt3: float = T.get_process_delta_time()
		t += dt3
		ew.cam.yaw_off = lerpf(-0.25, 0.2, clampf((t - 16.0) / 10.0, 0.0, 1.0))
		ew.cam.dist = lerpf(34.0, 27.0, clampf((t - 16.0) / 10.0, 0.0, 1.0))
	print("TRAILER OK %.1f s" % t)


# ================================================================= Store-Bilder (Kapitel 7.4)
## Ruhige Oberfläche für Werbebilder: Tutorial und Ziele erledigt, keine Abholblasen, keine Hinweise.
func _store_clean() -> void:
	if P.d.has("tut"):
		P.d.tut.step = DF.TUT_STEPS.size()
		P.d.tut.flood = true
	if P.d.has("goals"):
		P.d.goals.idx = DF.GOALS.size() + 99
	if P.d.has("pickups"):
		P.d.pickups.clear()
	P.d.intro_seen = true
	P.d.chests = {}
	if P.d.has("daily_gift"):
		P.d.daily_gift.day = P.day_index()
	P.d.stats.expeditions = maxi(5, int(P.d.stats.expeditions))


## Ziele-Leiste ausblenden (Werbebilder).
func _hide_goal(n: Node) -> void:
	for c in n.get_children():
		if c is Control and String(c.get_meta("guide", "")) == "goal":
			c.visible = false
			var p := c.get_parent()
			if p is PanelContainer:
				p.visible = false
		_hide_goal(c)


func store_shot(motif: String, out: String) -> void:
	_store_clean()
	var w = G.main.world
	if w.mode == "peace":
		await G.main.goto_base()
		await T._wait(0.3)
		w = G.main.world
	Engine.time_scale = 1.0
	_hide_goal(G.hud)
	var cam = w.cam
	match motif:
		"basis":
			var bp: Vector3 = w.bunker_node.global_position
			w.hero.global_position = bp + Vector3(3.5, 0, 6.5)
			cam.override_target = bp + Vector3(2.0, 0, 3.0)
			cam.dist = 46.0
			cam.yaw_off = 0.32
			cam.snap()
			await T._wait(3.0)
		"flut":
			P.d.week.start_day = P.day_index() - 6
			Guide.set_flood_diff(int(G.arg("fdiff", "2")))       # Albtraum: viele Gegner an den Mauern
			w.start_flood(false)
			await T._wait(0.2)
			w.skip_break()
			Engine.time_scale = 2.0
			var t := 0.0
			var bp2 := Vector2(w.bunker_node.global_position.x, w.bunker_node.global_position.z)
			while t < float(G.arg("maxt", "45")):
				await T._wait(0.5)
				t += 0.5
				var near: Array = w.horde.in_radius(bp2, 30.0)
				if near.size() >= int(G.arg("crowd", "40")):
					var c := Vector2.ZERO
					for e in near:
						c += e.p
					c /= near.size()
					cam.override_target = Vector3(c.x, 0, c.y).lerp(w.bunker_node.global_position, 0.25)
					cam.dist = 36.0
					cam.snap()
					break
			Engine.time_scale = 1.0
			await T._wait(0.4)
		"angriff":
			# Großangriff auf die Außenbasis der Expedition (viele Gegner auf einmal)
			w.admin_skip_phase()
			w.admin_skip_phase()
			cam.dist = 34.0
			Engine.time_scale = 2.0
			await T._wait(float(G.arg("wait", "14")))
			Engine.time_scale = 1.0
			await T._wait(0.3)
		"expedition", "vulkan":
			cam.dist = 30.0
			Engine.time_scale = 2.0
			await T._wait(float(G.arg("wait", "24")))
			Engine.time_scale = 1.0
			await T._wait(0.3)
		"helden":
			G.main.screens.open("heroes")
			await T._wait(1.5)
		"pad", "untertitel":
			# Prüfbilder: Gamepad-Fokus im Menü bzw. Untertitel und Farbfilter im Kampf
			if motif == "pad":
				G.main.screens.open("settings")
				await T._wait(0.3)
				Pc.nav.set_active(true)
				await T._wait(0.5)
			else:
				Dev.set_v("captions", true)
				A11y.apply(G.main)
				A11y.set_cb_mode(int(G.arg("cb", "1")))
				Captions.show_text("Alarm: Die Flut kommt!")
				Sfx.play_at("explosion_small", w.hero.global_position + Vector3(6, 0, 0))
				await T._wait(0.5)
		"boss":
			# Turm-Modus, Stockwerk 50: der Schleimkönig
			G.test_args["floor"] = G.arg("floor", "50")
			G.test_args["level"] = G.arg("level", "40")
			await preload("res://src/tests_modi.gd").new(T).shot("modi_turm")
			Engine.time_scale = 2.0
			await T._wait(float(G.arg("wait", "8")))
			Engine.time_scale = 1.0
			await T._wait(0.3)
	await T.get_tree().process_frame
	await T.get_tree().process_frame
	var img := T.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("STORESHOT %s %s %dx%d" % [motif, out, img.get_width(), img.get_height()])
