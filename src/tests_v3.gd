extends RefCounted
## Prüfungen für den Entwicklungsauftrag V3 (Etappe A): Bauzeiten, Juwelen, Mauern und Tore,
## Sammelblasen, Heldenstufen, Werkstatt-Ordnung, Umstellung alter Spielstände.
## Aufruf aus tests.gd (--selftest) oder allein mit --autotest=escape.

const D = preload("res://src/data.gd")
const Workshop = preload("res://src/screens/workshop.gd")

var T: Node                      # tests.gd (für _check und _wait)


func _init(tests: Node) -> void:
	T = tests


func run() -> void:
	_rules()
	await _world()
	await escape()
	_migration()


# ---------------------------------------------------------------- reine Spielregeln
func _rules() -> void:
	P.new_game()
	P.no_save = true
	# Bauzeiten: nichts wird ohne Wartezeit fertig
	for key in D.BUILDINGS:
		var def: Dictionary = D.BUILDINGS[key]
		var mx := 10 if def.cat in ["def", "prod", "core"] else (3 if def.cat == "wall" else (5 if def.cat in ["special", "trap"] else 1))
		for lv in range(1, mx + 1):
			if key == "bunker" and lv == 1:
				continue
			T._check(D.build_time(key, lv) > 0.0, "Bauzeit > 0: %s Stufe %d" % [key, lv])
	T._check(D.build_time("mg", 1) <= 60.0 and D.build_time("saege", 1) <= 60.0 and D.build_time("bunker", 2) <= 60.0, "erste Bauten höchstens eine Minute")
	T._check(D.build_time("bunker", 10) == 172800.0 and D.build_time("mg", 10) == 72000.0, "späte Bauten dauern Stunden")
	# Juwelenpreise laut Tabelle
	var exp := {60: 0, 300: 3, 1800: 11, 3600: 20, 14400: 52, 28800: 94, 86400: 260, 172800: 460}
	for s in exp:
		T._check(D.gem_cost(float(s)) == int(exp[s]), "Juwelenpreis %d s = %d (ist %d)" % [s, int(exp[s]), D.gem_cost(float(s))])
	T._check(D.gem_cost(61.0) == 2 and D.gem_cost(60.0) == 0 and D.gem_cost(30.0) == 0, "bis zu einer Minute gratis")
	# Beschleunigen
	P.add_many({"coins": 4000, "wood": 1400, "stone": 1400})
	var c := int(D.GRID_MAX / 2)
	P.bunker().level = 2
	var g0 := P.gems()
	var sg := P.place("saege", c - 9, c + 2)
	T._check(P.is_building(sg) and P.speed_cost(int(sg.id)) == 0, "Sägewerk: Restzeit unter 60 s ist gratis")
	T._check(P.finish_now(int(sg.id)) and not P.is_building(sg) and P.gems() == g0, "gratis fertiggestellt")
	T._check(P.upgrade(int(sg.id)) and P.speed_cost(int(sg.id)) == D.gem_cost(180.0), "Verbesserung kostet laut Tabelle (%d)" % P.speed_cost(int(sg.id)))
	T._check(P.prod_rate(sg) > 0.0 and sg.get("up", false), "Gebäude in Verbesserung arbeitet weiter")
	var cost := P.speed_cost(int(sg.id))
	T._check(P.finish_now(int(sg.id)) and int(sg.level) == 2 and P.gems() == g0 - cost, "Beschleunigen zieht %d Juwelen ab" % cost)
	# Mauern: ein Zug = ein Auftrag mit einer Drohne, Stücke nacheinander
	var busy0 := P.drones_busy()
	var walls0 := P.count("wall")
	for i in 5:
		P.place("wall", c - 8 + i, c - 8)
	T._check(P.count("wall") == walls0 + 5 and P.drones_busy() == busy0 + 1, "fünf Mauern belegen eine Drohne")
	var ends: Array = []
	for b in P.d.buildings:
		if b.key == "wall" and P.is_building(b):
			ends.append(float(b.done_at) - P.now())
	ends.sort()
	T._check(ends.size() == 5 and absf(float(ends[4]) - 20.0) < 1.0 and absf(float(ends[0]) - 4.0) < 1.0, "Mauern werden nacheinander fertig (4 s je Stück): %s" % str(ends))
	P.skip_time(25.0)
	T._check(P.drones_busy() == busy0, "Mauerauftrag fertig")
	# Mauern verbessern (ab Bunker 4), Aufträge zu je 25 Stück
	T._check(P.upgradable_walls().is_empty(), "Stein erst ab Bunker 4")
	P.bunker().level = 4
	P.add_many({"stone": 4000})
	P.d.res.stone = 4000
	var n := P.upgrade_walls()
	T._check(n == P.count("wall") and P.drones_busy() == busy0 + 1, "alle %d Mauern in einem Auftrag" % n)
	P.speed_up_builds(1.0e9)
	var all_stone := true
	for b in P.d.buildings:
		if b.key == "wall" and int(b.level) != 2:
			all_stone = false
	T._check(all_stone, "Mauern sind jetzt aus Stein")
	# Hindernisse wegräumen bringt Juwelen
	P._grow_obstacles(true)
	var ob := {}
	for b in P.d.buildings:
		if D.BUILDINGS[b.key].cat == "obstacle":
			ob = b
	T._check(not ob.is_empty(), "Hindernis gewachsen")
	if not ob.is_empty():
		P.add_many({"wood": 100, "stone": 100})
		var g1 := P.gems()
		T._check(P.clear_obstacle(int(ob.id)) == "", "Wegräumen startet")
		P.speed_up_builds(1.0e9)
		T._check(P.get_building(int(ob.id)).is_empty() and P.gems() > g1, "Hindernis weg, Juwelen erhalten")
	# tägliches Geschenk und Abholungen
	P.d.daily_gift.day = -1
	P.d.pickups.clear()
	P._check_daily()
	T._check(P.has_pickup("daily"), "tägliches Geschenk liegt bereit")
	var g2 := P.gems()
	P.claim_pickup(int(P.d.pickups[0].id))
	T._check(P.gems() == g2 + int(D.DAILY_GIFT[0]) or P.gems() > g2, "Geschenk bringt Juwelen")
	# Erfolge
	P.d.counters["walls"] = 12
	var g3 := P.gems()
	T._check(P.claim_achievement("walls") > 0 and P.gems() > g3 and P.claim_achievement("walls") == 0, "Erfolg einmal abholbar")
	# Laden: Testkauf, zusätzliche Drohne
	var Store = load("res://src/store.gd")
	var g4 := P.gems()
	T._check(Store.buy("gems_500") == "" and P.gems() == g4 + 500, "Testkauf schreibt Juwelen gut")
	var dt := P.drones_total()
	T._check(P.buy_drone() and P.drones_total() == dt + 1, "zusätzliche Baudrohne")
	# Heldenstufen
	P.unlock_hero("mika")
	var mw := 0
	for it in P.d.items:
		if it.slot == "weapon" and String(D.WEAPONS[it.key].hero) == "mika":
			mw += 1
	T._check(int(P.hero("mika").level) == 1 and mw == 1, "neuer Held: Stufe 1, eine Waffe")
	var s1: Dictionary = P.hero_stats("mika")
	P.d.heroes["mika"].level = 11
	var s11: Dictionary = P.hero_stats("mika")
	T._check(absf(float(s11.m.hp) - float(s1.m.hp) - 0.3) < 0.001 and absf(float(s11.m.dmg) - float(s1.m.dmg) - 0.2) < 0.001, "je Stufe +3 % Leben und +2 % Schaden")
	T._check(D.item_cap(1) == 1 and D.item_cap(9) == 4 and D.item_cap(40) == 10, "Ausrüstung hängt an der Heldenstufe")
	T._check(P.chapters_open("mika") == 3, "Kapitel nach Heldenstufe")
	P.d.heroes["mika"].level = 1
	# Werkstatt: feste Reihenfolge Held > Platz > Waffe > Seltenheit > Stufe
	for hk in D.HERO_ORDER:
		P.d.heroes[hk].unlocked = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var wkeys: Array = D.WEAPONS.keys()
	for i in 60:
		var it2: Dictionary
		if rng.randf() < 0.7:
			it2 = P.make_item("weapon", String(wkeys[rng.randi() % wkeys.size()]), rng.randi() % 4)
		else:
			it2 = P.make_item(["helmet", "vest", "charm"][rng.randi() % 3], "", rng.randi() % 4)
		it2.level = 1 + rng.randi() % 5
	var sorted: Array = Workshop.sort_items(P.d.items)
	var ok := true
	for i in range(1, sorted.size()):
		var ka: Array = Workshop.sort_key(sorted[i - 1])
		var kb: Array = Workshop.sort_key(sorted[i])
		for k in ka.size():
			if ka[k] != kb[k]:
				if ka[k] > kb[k]:
					ok = false
				break
	T._check(ok and sorted.size() == P.d.items.size(), "Werkstatt-Liste ist fest sortiert (%d Stücke)" % sorted.size())
	var seen_hero := -1
	var mono := true
	for it3 in sorted:
		if it3.slot == "weapon":
			var hi: int = D.HERO_ORDER.find(String(D.WEAPONS[it3.key].hero))
			if hi < seen_hero:
				mono = false
			seen_hero = hi
	T._check(mono, "Waffen stehen nach Helden geordnet")
	var st: Array = Workshop.stacks(sorted)
	T._check(st.size() < sorted.size(), "gleiche Stücke werden gestapelt (%d Zeilen für %d Stücke)" % [st.size(), sorted.size()])


# ---------------------------------------------------------------- Welt: Blasen und Tor
func _world() -> void:
	P.new_game()
	P.no_save = true
	P.add_many({"coins": 4000, "wood": 1400})
	var c := int(D.GRID_MAX / 2)
	var sg := P.place("saege", c + 6, c + 2)
	P.speed_up_builds(1.0e9)
	G.main.goto_base()
	var w = G.main.world
	await T._wait(0.3)
	w.hero.global_position = Vector3(-14, 0, -14)
	sg.last_collect = P.now() - 20.0 * 60.0
	w._check_production()
	var node = w.nodes[int(sg.id)]
	T._check(node.bubble != null and node.bubble.visible and node.bubble.state == 0, "nach 20 Minuten schwebt eine Sammelblase")
	T._check(node.bubble.amount_text == str(P.prod_stored(sg)), "Blase zeigt die Menge (%s)" % node.bubble.amount_text)
	sg.last_collect = P.now() - 9.0 * 3600.0
	w._check_production()
	T._check(node.bubble.state == 2 and node.stopped, "voller Speicher: rote Blase, Gebäude steht still")
	var before := P.prod_stored(sg)
	var wood := P.res("wood")
	P.d.res.wood = 0
	T._check(w._tap_bubble(node.bubble.screen_pos(w.cam.cam)), "Antippen der Blase sammelt ein")
	T._check(P.res("wood") == mini(before, P.cap("wood")) and not node.stopped, "Lager steigt genau um die Menge")
	P.d.res.wood = wood
	# Heranlaufen sammelt ein
	sg.last_collect = P.now() - 30.0 * 60.0
	w.hero.global_position = Vector3(node.mid.x, 0, node.mid.y + node.radius + 2.0)
	var wood2 := P.res("wood")
	w._check_production()
	T._check(P.res("wood") > wood2, "Heranlaufen sammelt ein")
	# volles Lager: Rest bleibt in der Blase
	sg.last_collect = P.now() - 5.0 * 3600.0
	P.d.res.wood = P.cap("wood") - 10
	w.hero.global_position = Vector3(-14, 0, -14)
	w._check_production()
	w._tap_bubble(node.bubble.screen_pos(w.cam.cam))
	w._check_production()
	T._check(P.res("wood") == P.cap("wood") and node.bubble.visible, "volles Lager: der Rest bleibt in der Blase")
	# Tor der Startbasis: öffnet für den Helden, sperrt nie
	var gate = null
	for id in w.nodes:
		if w.nodes[id].gate:
			gate = w.nodes[id]
	T._check(gate != null, "Startbasis hat ein Tor")
	if gate != null:
		w.hero.global_position = Vector3(gate.mid.x, 0, gate.mid.y - 2.5)
		await T._wait(1.2)
		T._check(gate.open_k > 0.9, "Tor öffnet sich für den Helden (%.2f)" % gate.open_k)
		w.hero.global_position = Vector3(-14, 0, -14)
		await T._wait(2.5)
		T._check(gate.open_k < 0.1, "Tor schließt hinter dem Helden (%.2f)" % gate.open_k)
		T._check(not w.field.blocks_player(gate.mid) and w.field.structure_at(gate.mid) == gate, "Tor: frei für Freunde, Hindernis für Gegner")


# ---------------------------------------------------------------- Ausbruchsversuch
## Ein geschlossener Mauerring ohne Tor hält den Helden: zu Fuß, mit Rolle, mit jedem Fahrzeug, gerade und schräg.
## Mit Tor kommt er in unter zehn Sekunden hinaus.
func escape() -> void:
	P.new_game()
	P.no_save = true
	for b0 in P.d.buildings.duplicate():
		if b0.key == "wall" or b0.key == "tor":
			P.d.buildings.erase(b0)
	P.bunker().level = 4
	var c := int(D.GRID_MAX / 2)
	# Ring mit 6 Feldern Abstand um den Bunker; zwei Seiten als Treppe (schräge Mauern)
	var r := 7
	var cells := {}
	for i in range(-r, r + 1):
		for p in [[c + i, c - r], [c + i, c + r], [c - r, c + i], [c + r, c + i]]:
			cells[Vector2i(int(p[0]), int(p[1]))] = true
	# Ecken unten abschneiden: rein diagonale Mauer (nur über Eck verbunden)
	for k in 4:
		for sx in [-1, 1]:
			cells.erase(Vector2i(c + sx * (r - k), c + r))
			cells.erase(Vector2i(c + sx * r, c + r - k))
	for k in 5:
		for sx in [-1, 1]:
			cells[Vector2i(c + sx * (r - 4 + k), c + r - k)] = true
	for cl in cells:
		if P.cells_free(cl.x, cl.y, 1, 1):
			P._add_building("wall", cl.x, cl.y, 0, 1)
	for vk in D.VEHICLES:
		P.d.vehicles[vk].owned = true
	T._check(P.enclosed(), "Ring ohne Tor gilt als zugemauert")
	G.main.goto_base()
	var w = G.main.world
	await T._wait(0.3)
	var hero = w.hero
	var lim: float = (r - 0.4) * D.CELL
	var home: Vector2 = w.bunker_node.mid
	var escaped := 0
	var runs := 0
	var modes: Array = ["fuss", "rolle"]
	for vk in D.VEHICLE_ORDER:
		modes.append(vk)
	for mode in modes:
		if hero.mounted:
			hero.dismount()
		if mode != "fuss" and mode != "rolle":
			if hero.veh_node != null:
				hero.veh_node.queue_free()
				hero.veh_node = null
			hero.give_vehicle(String(mode))
			hero.mount()
		for a in 8:
			var dir := Vector2(cos(a * PI / 4.0 + 0.02), sin(a * PI / 4.0 + 0.02))
			var start: Vector2 = home + dir * (w.bunker_node.radius + 3.5)
			hero.global_position = Vector3(start.x, 0, start.y)
			hero.test_wish = dir
			for step in 5:
				if mode == "rolle":
					hero.dodge_n = 1
					hero._vel = dir * 7.0
					hero.dodge()
				await T._wait(0.12)
				if G.arg("trace") == "%s%d" % [mode, a]:
					print("  spur ", mode, a, " ", hero.pos2(), " blockiert=", w.field.blocks_player(hero.pos2()), " dash=", hero.dash_t)
			var d: Vector2 = hero.pos2() - home
			runs += 1
			if maxf(absf(d.x), absf(d.y)) > lim + 1.0:
				escaped += 1
				print("AUSBRUCH: %s Richtung %d bei %s" % [mode, a, str(hero.pos2())])
	hero.test_wish = Vector2.ZERO
	if hero.mounted:
		hero.dismount()
	T._check(escaped == 0, "kein Ausbruch aus dem Mauerring (%d Versuche, %d gelungen)" % [runs, escaped])
	# mit Tor: hinaus in unter zehn Sekunden
	var top := {}
	for b in P.d.buildings:
		if b.key == "wall" and int(b.y) == c - r and int(b.x) == c:
			top = b
	var gate: Dictionary = P.wall_to_gate(int(top.id), true)
	T._check(not gate.is_empty() and not P.enclosed(), "Tor eingesetzt: nicht mehr zugemauert")
	await T._wait(0.2)
	var gs := P.size_of("tor", int(gate.rot))
	var gm: Vector2 = w.rect_center(int(gate.x), int(gate.y), gs)
	hero.global_position = Vector3(gm.x, 0, home.y - w.bunker_node.radius - 3.0)
	hero.test_wish = Vector2(0, -1)
	var t0: float = w.time
	var out := false
	for i in 40:
		await T._wait(0.05)
		if hero.pos2().y < gm.y - 3.0:
			out = true
			break
	hero.test_wish = null
	T._check(out and w.time - t0 < 10.0, "durch das Tor hinaus in %.1f s" % (w.time - t0))
	if G.autotest == "escape":
		print("RESULT mode=escape win=%s runs=%d escaped=%d" % [escaped == 0 and out, runs, escaped])


# ---------------------------------------------------------------- alter Spielstand
func _migration() -> void:
	P.new_game()
	P.no_save = true
	for b0 in P.d.buildings.duplicate():
		if b0.key == "wall" or b0.key == "tor":
			P.d.buildings.erase(b0)
	P.bunker().level = 5
	var c := int(D.GRID_MAX / 2)
	var r := 6
	for i in range(-r, r + 1):
		for p in [[c + i, c - r], [c + i, c + r], [c - r, c + i], [c + r, c + i]]:
			if P.cells_free(int(p[0]), int(p[1]), 1, 1):
				P._add_building("wall", int(p[0]), int(p[1]), 0, 1)
	# so sah ein Stand der Version 2 aus: keine der neuen Felder, Mauern ohne eigene Bauart
	for k in ["gems_log", "pickups", "outposts", "bestiary", "achievements", "counters", "flags_owned", "next_pickup", "next_job", "drones_bought", "flag_color", "obstacle_day", "daily_gift", "training"]:
		P.d.erase(k)
	P.d.res.erase("gems")
	P.d.version = 2
	P.d = JSON.parse_string(JSON.stringify(P.d))
	var walls := P.count("wall")
	var items: int = P.d.items.size()
	P._needs_migration = true
	P._after_load()
	P.social.s = P.d.social
	P.social.ensure()
	T._check(int(P.d.version) == 3 and P.gems() == 100, "alter Stand: Version 3, Startguthaben Juwelen")
	T._check(P.count("tor") == 1 and P.count("wall") == walls - 2 and not P.enclosed(), "geschlossener Mauerring bekommt genau ein Tor")
	var stone := true
	for b in P.d.buildings:
		if (b.key == "wall" or b.key == "tor") and int(b.level) != 2:
			stone = false
	T._check(stone, "Mauern behalten ihre Stärke (Stein bei Bunker 5)")
	T._check(P.d.items.size() == items and P.bunker_level() == 5, "Gebäude, Helden und Gegenstände bleiben")
	G.main.goto_base()
	await T._wait(0.3)
	var w = G.main.world
	T._check(not w.field.blocks_player(w.hero.pos2()), "Held steht nach der Umstellung frei")
