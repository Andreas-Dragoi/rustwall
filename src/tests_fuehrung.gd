extends RefCounted
## Prüfungen für Paket F (Spielerführung und Komfort): Juwelen auf Konto-Ebene, Tutorial, Ziele-Leiste,
## Rückkehr-Zusammenfassung, Bau-Warteschlange, Mauer-Reihe, Mauern ziehen, Flut-Schwierigkeit, Wellen-Vorschau,
## Tutorial-Flut, Turmziel, Gebäudeschaden, Bildrate, Pause im Hintergrund, Helden-Seite, Hilfe.
## Aufruf aus tests.gd (--selftest).

const D = preload("res://src/data.gd")
const DF = preload("res://src/data_fuehrung.gd")
const Guide = preload("res://src/guide.gd")
const ScreenFit = preload("res://src/screen_fit.gd")

var T: Node


func _init(tests: Node) -> void:
	T = tests


func run() -> void:
	_wallet()
	_tutorial_rules()
	_goals()
	_return()
	_queue()
	_walls()
	_flood_rules()
	await _world()
	await _screens()
	P.new_game()
	P.no_save = true


# ---------------------------------------------------------------- Juwelen gehören allen Städten
func _wallet() -> void:
	P.new_game()
	P.no_save = true
	var keep: Dictionary = P.cities.duplicate(true)
	# Umstellung: ohne "wallet" wird das Guthaben aus den Städten genommen (höchster Stand, nicht die Summe)
	P.cities.erase("wallet")
	P._wallet_init()
	T._check(P.cities.has("wallet") and int(P.cities.wallet) >= 0, "Konto-Guthaben angelegt (%s)" % str(P.cities.get("wallet")))
	# Ablauf mit Speichern (ohne in Dateien zu schreiben: nur Pull/Push)
	P.no_save = false
	P.cities["wallet"] = 77
	P._wallet_pull()
	var a := P.gems()
	P.d.res.gems = 77
	P.add_gems(5, "Test")
	var b := int(P.cities.wallet)
	P.spend_gems(2, "Test")
	var c := int(P.cities.wallet)
	P.new_game()                      # wie eine neue Stadt: bekäme 100 Start-Juwelen …
	P._wallet_pull()                  # … übernimmt aber das Konto
	var e := P.gems()
	P.no_save = true
	P._dirty = false
	T._check(a == 77 and b == 82 and c == 80, "Juwelen laufen über das Konto (%d, %d, %d)" % [a, b, c])
	T._check(e == 80, "neue Stadt bekommt keine neuen Start-Juwelen (%d)" % e)
	P.cities = keep


# ---------------------------------------------------------------- Tutorial (Regeln)
func _tutorial_rules() -> void:
	P.new_game()
	P.no_save = true
	T._check(Guide.tut_key() == "laufen" and not bool(P.d.tut.flood), "neues Spiel beginnt das Tutorial")
	Guide.tut_next(true)
	T._check(Guide.tut_key() == "blase" and (P.d.tut.skipped as Array).has("laufen"), "Schritt einzeln überspringbar")
	P._check_daily()
	Guide.tut_check(null)
	T._check(Guide.tut_key() == "blase", "Blase: wartet auf das Geschenk")
	P.claim_pickup(int(P.d.pickups[0].id))
	Guide.tut_check(null)
	T._check(Guide.tut_key() == "bauen", "Blase abgeholt: weiter zum Bauen")
	var cc := int(D.GRID_MAX / 2)
	P.place("saege", cc + 6, cc + 2)
	Guide.tut_check(null)
	T._check(Guide.tut_key() == "beschleunigen", "Sägewerk gesetzt: weiter zum Beschleunigen")
	for bb in P.d.buildings:
		if bb.key == "saege":
			P.finish_now(int(bb.id))
	Guide.tut_check(null)
	T._check(Guide.tut_key() == "uebung" and Guide.tut_flood_open(), "fertiggestellt: weiter zur Übungsflut")
	Guide.tut_skip_all()
	T._check(Guide.tut_key() == "", "Tutorial lässt sich ganz beenden")
	Guide.tut_restart()
	T._check(Guide.tut_key() == "laufen", "Tutorial neu starten")
	# alter Stand ohne Tutorial-Felder: als erledigt markieren, erfüllte Ziele überspringen
	P.new_game()
	P.no_save = true
	P.place("saege", cc + 6, cc + 2)
	P.speed_up_builds(1.0e9)
	P.d.erase("tut")
	P.d.erase("goals")
	P._ensure_fields()
	T._check(Guide.tut_key() == "" and bool(P.d.tut.flood), "alter Stand: Tutorial gilt als erledigt")
	T._check(int(P.d.goals.idx) >= 1, "alter Stand: erfülltes erstes Ziel übersprungen (Ziel %d)" % int(P.d.goals.idx))


# ---------------------------------------------------------------- Ziele-Leiste
func _goals() -> void:
	P.new_game()
	P.no_save = true
	T._check(DF.GOALS.size() >= 38, "Kette mit %d Zielen" % DF.GOALS.size())
	var last_bunker := 0
	for g in DF.GOALS:
		T._check(String(g.t) in ["built", "level", "stat"] and (String(g.t) != "built" or D.BUILDINGS.has(String(g.key))) and not (g.reward as Dictionary).is_empty(), "Ziel gültig: %s" % Guide.goal_text(g))
		if String(g.t) == "level" and String(g.key) == "bunker":
			last_bunker = int(g.n)
	T._check(last_bunker == 6, "Kette reicht bis Bunker 6")
	var g0 := Guide.goal()
	T._check(String(g0.key) == "saege" and not Guide.goal_ready() and Guide.goal_claim().is_empty(), "erstes Ziel: Sägewerk, noch nicht abholbar")
	var cc := int(D.GRID_MAX / 2)
	P.place("saege", cc + 6, cc + 2)
	P.speed_up_builds(1.0e9)
	var coins := P.res("coins")
	T._check(Guide.goal_ready(), "Sägewerk fertig: Ziel erfüllt")
	var rw := Guide.goal_claim()
	T._check(not rw.is_empty() and P.res("coins") > coins and int(P.d.goals.idx) == 1, "Belohnung abgeholt, nächstes Ziel")
	# nach der Kette: erzeugte Ziele
	P.d.goals.idx = DF.GOALS.size()
	var gg := Guide.goal()
	var pr: Array = Guide.goal_progress(gg)
	T._check(gg.has("base") and int(pr[0]) == 0 and int(pr[1]) > 0, "erzeugtes Ziel beginnt bei 0 (%s)" % Guide.goal_text(gg))
	P.d.stats.kills = int(P.d.stats.kills) + int(gg.n)
	T._check(Guide.goal_ready() and not Guide.goal_claim().is_empty() and int(P.d.goals.idx) == DF.GOALS.size() + 1, "erzeugtes Ziel abholbar, danach das nächste")
	T._check(Guide.goal_text(Guide.goal()) != "", "es gibt immer ein nächstes Ziel")


# ---------------------------------------------------------------- Rückkehr-Zusammenfassung
func _return() -> void:
	P.new_game()
	P.no_save = true
	var cc := int(D.GRID_MAX / 2)
	var sg := P.place("saege", cc + 6, cc + 2)
	P.speed_up_builds(1.0e9)
	var mg := P.place("mg", cc - 8, cc + 4)
	mg.done_at = P.now() - 10.0
	P.d["last_seen"] = P.now() - 3.2 * D.DAY_SECONDS
	sg.last_collect = P.now() - 3.0 * 3600.0
	Guide.ensure(P.d)
	T._check(not Guide.away.is_empty(), "nach drei Tagen: Rückkehr erkannt")
	P._time_passed()
	var rep := Guide.away_report()
	T._check(float(rep.get("days", 0.0)) > 3.0 and int(rep.get("gift", 0)) == 3 * DF.RETURN_GIFT_PER_DAY, "Rückkehr-Geschenk für drei Tage (%s)" % str(rep.get("gift")))
	var txt := str(rep.get("lines", []))
	T._check(txt.contains("MG-Turm") and txt.contains("Holz"), "Zusammenfassung nennt fertige Bauten und volle Speicher: %s" % txt)
	T._check(Guide.away_report().is_empty(), "Zusammenfassung erscheint nur einmal")
	P.d["last_seen"] = P.now() - 3600.0
	Guide.ensure(P.d)
	T._check(Guide.away.is_empty(), "nach einer Stunde keine Zusammenfassung")


# ---------------------------------------------------------------- Bau-Warteschlange
func _queue() -> void:
	P.new_game()
	P.no_save = true
	P.add_many({"coins": 4000, "wood": 1400, "stone": 1400})
	var cc := int(D.GRID_MAX / 2)
	P.place("saege", cc + 6, cc + 2)
	P.place("mg", cc - 8, cc + 4)
	T._check(P.can_build("lager") == "Alle Baudrohnen sind beschäftigt", "beide Drohnen beschäftigt")
	T._check(Guide.queue_build("lager", cc + 6, cc - 6, 0) == "" and Guide.queue().size() == 1, "Lager vorgemerkt")
	T._check(Guide.queue_build("lager", cc + 6, cc - 6, 0) != "", "derselbe Platz kann nicht doppelt vorgemerkt werden")
	Guide.queue_tick()
	T._check(P.count("lager") == 0 and Guide.queue().size() == 1, "wartet, solange keine Drohne frei ist")
	P.speed_up_builds(1.0e9)
	P._time_passed()
	T._check(P.count("lager") == 1 and Guide.queue().is_empty(), "Drohne frei: vorgemerkter Bau startet von selbst")
	# Verbesserung vormerken
	var mg := {}
	for b in P.d.buildings:
		if b.key == "mg":
			mg = b
	P.bunker().level = 2
	var busy := P.drones_busy() >= P.drones_total()
	T._check(Guide.queue_upgrade(int(mg.id)) == "" and Guide.queued_upgrade(int(mg.id)), "Verbesserung vorgemerkt (Drohnen beschäftigt: %s)" % busy)
	P.speed_up_builds(1.0e9)
	P._time_passed()
	T._check(int(mg.level) == 2 or P.is_building(mg), "vorgemerkte Verbesserung gestartet")
	Guide.queue_build("lager", cc + 12, cc - 8, 0)
	Guide.queue_remove(0)
	T._check(Guide.queue().is_empty(), "Vormerkung lässt sich löschen")


# ---------------------------------------------------------------- Mauer-Reihe
func _walls() -> void:
	P.new_game()
	P.no_save = true
	P.bunker().level = 4
	P.add_many({"coins": 4000, "wood": 1400, "stone": 1400})
	P.d.res.stone = 1400
	var cc := int(D.GRID_MAX / 2)
	for i in 6:
		P.place("wall", cc - 8 + i, cc - 9)
	P.place("wall", cc - 8, cc - 8)            # ein Stück quer dazu
	P.speed_up_builds(1.0e9)
	var first := {}
	for b in P.d.buildings:
		if b.key == "wall" and int(b.x) == cc - 6 and int(b.y) == cc - 9:
			first = b
	var row: Array = Guide.wall_row(int(first.id))
	T._check(row.size() == 6, "Reihe erkannt (%d Stück)" % row.size())
	var pv: Dictionary = Guide.wall_row_preview(row)
	T._check(int(pv.n) == 6 and int(pv.hp1) > int(pv.hp0) and int(pv.cost.get("stone", 0)) == 6 * int(D.WALL_UP_COST[1].stone), "Vorschau: Kosten und Haltbarkeit vorher/nachher")
	var busy0 := P.drones_busy()
	var n := Guide.upgrade_wall_list(row)
	T._check(n == 6 and P.drones_busy() == busy0 + 1, "ganze Reihe als ein Auftrag (%d)" % n)
	P.speed_up_builds(1.0e9)
	T._check(int(first.level) == 2, "Reihe ist aus Stein")
	# Vorschau der Werte bei Stufenaufstieg
	for k in ["mg", "saege", "bunker", "lager"]:
		var up: Array = Guide.upgrade_preview(k, 2)
		T._check(up.size() > 0 and String(up[0][2]) != String(up[0][3]), "Vorschau vorher/nachher: %s" % k)


# ---------------------------------------------------------------- Flut-Regeln
func _flood_rules() -> void:
	P.new_game()
	P.no_save = true
	P.d.week.number = 6
	var fl := D.flood_def(6, 4)
	fl["mix"] = D.flood_mix(6)
	var w1 := Guide.wave_text(fl, 1, int(fl.waves))
	var wl := Guide.wave_text(fl, int(fl.waves), int(fl.waves))
	T._check(w1.contains("Schleimling") and wl.contains("Boss") and wl.contains("Helm"), "Wellen-Vorschau: %s / %s" % [w1, wl])
	T._check(Guide.flood_diff() == 0, "Schwierigkeit: Normal als Vorgabe")
	Guide.set_flood_diff(2)
	var fd := D.flood_def(6, 4)
	var t0 := int(fd.total)
	Guide.apply_flood(fd, false, false)
	T._check(int(fd.total) > t0 and int(fd.diff) == 2, "Albtraum: mehr Gegner (%d statt %d)" % [int(fd.total), t0])
	var res := {"win": true, "stars": 2, "points": 100}
	var coins := P.res("coins")
	Guide.flood_end(res, "flood", true, false)
	T._check(res.has("bonus") and P.res("coins") > coins and int(res.points) > 100, "Albtraum: Zusatzbeute (%s)" % str(res.get("bonus")))
	P.d.week.number = 7
	T._check(Guide.flood_diff() == 0, "neue Woche: wieder Normal")
	var tf := D.flood_def(1, 1)
	Guide.apply_flood(tf, true, true)
	T._check(int(tf.waves) == 2 and int(tf.total) == int(DF.TUT_FLOOD.total) and not bool(tf.boss), "Tutorial-Flut ist klein")


# ---------------------------------------------------------------- in der Welt
func _world() -> void:
	P.new_game()
	P.no_save = true
	P.d.tut.step = DF.TUT_STEPS.size()
	P.add_many({"coins": 4000, "wood": 1400, "stone": 1400})
	var cc := int(D.GRID_MAX / 2)
	var sg := P.place("saege", cc + 6, cc + 2)
	var mg := P.place("mg", cc - 8, cc + 4)
	P.speed_up_builds(1.0e9)
	G.main.goto_base()
	await T._wait(0.3)
	var w = G.main.world
	# Turmziel je Turm
	mg["aim"] = "strong"
	var s = w.nodes[int(mg.id)]
	s.queue_free()
	w.nodes.erase(int(mg.id))
	w._sync()
	s = w.nodes[int(mg.id)]
	T._check(s.tower != null and s.tower.aim == "strong", "Turmziel wird aus dem Spielstand übernommen")
	var me: Vector2 = s.tower.pos2()
	var near = w.horde.spawn(D.E_SLIME, me + Vector2(3, 0))
	var strong = w.horde.spawn(D.E_BRUTE, me + Vector2(7, 0))
	T._check(s.tower._aim_target(w.horde, me, 12.0) == strong, "„Stärkster“ zielt auf den Brocken")
	s.tower.aim = "near"
	T._check(s.tower._aim_target(w.horde, me, 12.0) == near, "„Nächster“ zielt auf den nahen Schleimling")
	s.tower.aim = "boss"
	T._check(s.tower._aim_target(w.horde, me, 12.0) == null, "„Boss“ ohne Boss: Standardwahl")
	w.horde.clear()
	# Gebäudeschaden bleibt gespeichert
	var ss = w.nodes[int(sg.id)]
	ss.hp = ss.max_hp * 0.5
	Guide.store_damage(w)
	T._check(absf(float(sg.get("dmg", 0.0)) - 0.5) < 0.02, "Schaden im Spielstand (%s)" % str(sg.get("dmg")))
	ss.queue_free()
	w.nodes.erase(int(sg.id))
	w._sync()
	ss = w.nodes[int(sg.id)]
	T._check(absf(ss.hp / ss.max_hp - 0.5) < 0.02, "nach Neuaufbau beschädigt (%.2f)" % (ss.hp / ss.max_hp))
	ss.hp = ss.max_hp
	Guide.store_damage(w)
	T._check(not sg.has("dmg"), "repariert: kein Schaden mehr gespeichert")
	# Mauern ziehen: Felder dazwischen werden aufgefüllt
	var walls0 := P.count("wall")
	w.begin_place("wall")
	w._paint_line(Vector2i(cc - 10, cc - 12), Vector2i(cc - 4, cc - 12))
	T._check(P.count("wall") == walls0 + 5, "Mauer ziehen füllt die Lücke (%d)" % (P.count("wall") - walls0))
	w._paint_line(Vector2i(cc - 10, cc - 11), Vector2i(cc - 7, cc - 8))
	T._check(P.count("wall") >= walls0 + 9, "schräg gezogen: ohne Lücken über Eck (%d)" % (P.count("wall") - walls0))
	w.cancel_edit()
	# Vormerken über den Platzier-Modus
	P.speed_up_builds(1.0e9)
	P.bunker().level = 2
	P.place("mg", cc + 10, cc + 6)
	P.place("lager", cc - 12, cc - 4)
	w.begin_place("kanone", true)
	T._check(w.editing() and w.queue_mode, "Platz wählen für einen vorgemerkten Bau")
	w.cancel_edit()
	# Alle abholen: Produktion und Geschenke
	sg.last_collect = P.now() - 2.0 * 3600.0
	P.add_pickup("test", "bunker", {"coins": 5}, "Test")
	w._check_production()
	w._sync_pickups()
	var pk: int = P.d.pickups.size()
	w.collect_all()
	T._check(P.d.pickups.size() < pk and P.prod_stored(sg) == 0, "„Alle abholen“ holt Blasen und Geschenke")
	# Bildrate im Akku-Sparmodus
	P.d.settings["akku"] = true
	var f_peace := ScreenFit.fps_target()
	# Tutorial-Flut: leicht, ohne Verlust, verbraucht nicht den Übungsalarm
	var pday := int(P.d.week.practice_day)
	P.d.tut.flood = false
	w.start_flood(true, true)
	T._check(w.tutorial_flood and w.wave_count == 2 and int(w.flood.total) == int(DF.TUT_FLOOD.total), "Tutorial-Flut läuft (2 Wellen)")
	var f_battle := ScreenFit.fps_target()
	T._check(f_peace == DF.FPS_CALM and f_battle == mini(DF.FPS_BATTLE, 60 if P.d.settings.get("fps60", true) else 30), "Akku-Sparmodus: %d in der Basis, %d im Kampf" % [f_peace, f_battle])
	P.d.settings.erase("akku")
	T._check(w.break_left <= 0.0 and Guide.wave_text(w.flood, 2, 2) != "", "Vorschau der nächsten Welle")
	# App geht in den Hintergrund: Kampf pausiert
	var paused: bool = G.hud.guide.pause_battle()
	T._check(paused and G.main.get_tree().paused, "App im Hintergrund: Flut pausiert")
	G.hud._resume()
	var lost := P.res("wood")
	w._finish(false)
	T._check(bool(P.d.tut.flood) and int(P.d.week.practice_day) == pday and P.res("wood") >= lost, "Tutorial-Flut: erledigt, ohne Verlust, Übungsalarm bleibt")
	T._check(w.result.has("bonus"), "Tutorial-Flut: Belohnung")
	G.hud._close_modal()
	w.back_to_peace()
	await T._wait(0.2)
	T._check(not w.tutorial_flood and w.mode == "peace", "zurück im Friedensbetrieb")
	# HUD: Ziele-Leiste sichtbar, Hilfe im Menü
	G.hud._rebuild()
	await T._wait(0.1)
	T._check(G.hud._goal != null and is_instance_valid(G.hud._goal) and G.hud._goal.is_visible_in_tree(), "Ziele-Leiste ist sichtbar")
	# Flut-Dialog mit Schwierigkeit und Vorschau
	P.d.week.start_day = P.day_index() - 6
	P.d.week.flood_done = false
	G.hud._ask_flood()
	await T._wait(0.1)
	T._check(G.hud.modal_open(), "Flut-Dialog mit Vorschau öffnet")
	G.hud._close_modal()
	P.d.week.start_day = P.day_index()


# ---------------------------------------------------------------- Bildschirme
func _screens() -> void:
	P.debug_setup(4)
	var sc = G.main.screens
	sc.open("heroes", "weapons")
	await T._wait(0.3)
	T._check(sc.is_open() and int(sc.st.tab) == 1, "Helden-Seite: Reiter Waffen")
	var key := String(P.d.hero_sel)
	T._check(D.hero_weapons(key).size() == 15, "15 Waffen je Held")
	# Schnellwechsel: zweite besessene Waffenart ausrüsten
	var kinds: Array = []
	for wk in D.hero_weapons(key):
		for it in P.d.items:
			if String(it.slot) == "weapon" and String(it.key) == String(wk):
				kinds.append(it)
				break
	if kinds.size() >= 2:
		T._check(P.equip(key, int(kinds[1].id)) and int(P.hero(key).weapon) == int(kinds[1].id), "Schnellwechsel rüstet um")
	sc.close()
	for i in DF.HELP.size():
		sc.open("hilfe", {"tab": i})
		await T._wait(0.15)
		T._check(sc.is_open() and sc.screen == "hilfe", "Hilfe-Seite: %s" % String(DF.HELP[i].title))
		sc.close()
	T._check(DF.TIPS.size() >= 10, "Ladebildschirm hat %d Tipps" % DF.TIPS.size())
	# Oberfläche: sichere Ränder und Größe
	var root: Control = G.hud.root
	var keep := root.scale
	P.d.settings["ui_size"] = 2
	G.hud.guide.fit_root()
	T._check(absf(root.scale.x - float(DF.UI_SIZES[2][1])) < 0.01, "Oberflächengröße „Groß“ skaliert das HUD")
	P.d.settings.erase("ui_size")
	G.hud.guide.fit_root()
	T._check(root.scale == keep or root.scale == Vector2.ONE, "Oberfläche zurück")
