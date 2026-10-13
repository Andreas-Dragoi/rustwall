extends RefCounted
## Prüfungen für V6 Paket B (Basis- und Flut-Tiefe): Forschungsbaum (Vorraum, Labor, Kosten, Zeit, Wirkungen, Bildschirm),
## klügere Belagerung (Brecher zur schwächsten Mauer, Flieger um die Luftabwehr, Leitern), Wetter der Flut, Flut-Rückblick
## (gespielt und berechnet), Layout-Codes und Layout-Test, Mauer-Schäden und Reparatur, Funde beim Räumen, verletzte
## Bewohner, Wasser-Spritzer, Mitteilungen, Bewertungs-Hinweis, Vibration.
## Aufruf aus tests.gd (--selftest) und allein mit --autotest=basis.

const D = preload("res://src/data.gd")
const DB = preload("res://src/data_basis.gd")
const R = preload("res://src/research.gd")
const FW = preload("res://src/flood_weather.gd")
const Replay = preload("res://src/flood_replay.gd")
const BState = preload("res://src/basis_state.gd")
const LayoutCode = preload("res://src/layout_code.gd")
const Notify = preload("res://src/notify.gd")
const BasisUI = preload("res://src/basis_ui.gd")
const Nature = preload("res://src/base_nature.gd")
const Weather = preload("res://src/weather.gd")
const Siege = preload("res://src/siege.gd")

var T: Node


func _init(tests: Node) -> void:
	T = tests


func run() -> void:
	FW.force = "klar"
	await _research()
	await _siege()
	await _weather()
	await _replay_and_repair()
	await _layouts()
	await _finds()
	await _injured_and_water()
	await _mobile()
	FW.force = ""
	G.main.goto_base()
	await T._wait(0.3)


## Für ui_test.gd (Bilder, Zufallsklick): Werkstatt und Labor, ein paar Forschungen, eine laufende, zwei Rückblicke.
static func ui_rich() -> void:
	var c := int(D.GRID_MAX / 2)
	for e in [["werkstatt", c - 12, c + 6], ["labor", c + 8, c + 8]]:
		var b := P._add_building(String(e[0]), int(e[1]), int(e[2]), 0, 3)
		b.done_at = 0.0
	R.ensure(P.d)
	for k in ["t_optik", "t_lader", "t_mauer", "t_munition", "w_lager", "w_drohnen", "h_gurte"]:
		P.d.research.done.append(k)
	P.d.research.cur = "t_fallen"
	P.d.research.t0 = P.now() - 1200.0
	P.d.research.end = P.now() + 2400.0
	var fd := D.flood_def(int(P.d.week.number), P.bunker_level())
	BState.ensure(P.d)
	P.d.replays = []
	Replay.store(Replay.simulate(fd, true, 1.2, {"stars": 2, "hp_ratio": 0.7}))
	Replay.store(Replay.simulate(fd, false, 0.6, {"stars": 0}))
	P.d.replays[0]["mode"] = "flood"
	P.d.replays[0]["calc"] = false
	P.d.replays[0]["weather"] = "regen"
	P.d.replays[0]["night"] = true


func _fresh(bl: int) -> void:
	P.debug_setup(bl)
	P.no_save = true
	P.speed_up_builds(1.0e9)
	Weather.force = "tag"
	G.main.goto_base()
	await T._wait(0.6)


# ================================================================= Forschung
func _research() -> void:
	P.new_game()
	P.no_save = true
	R.ensure(P.d)
	T._check(R.tier_why(0) != "" and R.state("t_optik") == "locked", "Forschung: ohne Werkstatt gesperrt")
	await _fresh(4)
	var c := int(D.GRID_MAX / 2)
	var ws := P._add_building("werkstatt", c - 12, c + 6, 0, 1)
	ws.done_at = 0.0
	P.buildings_changed.emit()
	T._check(R.prelab_ok() and R.state("t_optik") == "open" and R.state("w_lager") == "open" and R.state("h_gurte") == "open", "Vorraum: drei Wurzeln über die Werkstatt")
	T._check(R.why_not("t_lader").contains("Labor") or R.why_not("t_lader").begins_with("Erst"), "Reihe 2 braucht Labor und Voraussetzung (%s)" % R.why_not("t_lader"))
	var coins0 := P.res("coins")
	var rng0: float = G.main.world.tower_range_k()
	T._check(R.start("t_optik") == "" and R.current() == "t_optik", "Forschung startet")
	T._check(P.res("coins") == coins0 - int(R.cost("t_optik").coins), "Kosten bezahlt")
	T._check(R.start("w_lager") != "", "nur ein Forschungsplatz")
	T._check(R.speed_cost() > 0 and R.left() > 60.0, "Beschleunigen kostet Juwelen (%d)" % R.speed_cost())
	var g0 := P.gems()
	T._check(R.finish_now() and R.is_done("t_optik") and P.gems() < g0, "mit Juwelen fertig")
	T._check(absf(R.bonus("tower_range") - 0.06) < 0.001 and G.main.world.tower_range_k() > rng0 + 0.05, "Wirkung: Reichweite +6 %")
	# Zeit läuft wie eine Bauzeit (auch ohne Spiel)
	T._check(R.start("w_lager") == "", "zweite Wurzel startet")
	var cap0 := P.cap("wood")
	P.skip_time(R.time_for("w_lager") + 2.0)
	T._check(R.is_done("w_lager") and R.current() == "", "fertig nach Ablauf der Zeit")
	T._check(P.cap("wood") > cap0 * 1.09, "Lager +10 %% (%d → %d)" % [cap0, P.cap("wood")])
	# Labor öffnet die tieferen Reihen
	var lab := P._add_building("labor", c + 8, c + 8, 0, 1)
	lab.done_at = 0.0
	T._check(R.labor_level() == 1 and R.state("t_lader") == "open" and R.state("t_wetter") == "locked", "Labor: Reihe 2 offen, Reihe 4 gesperrt")
	for k in ["t_lader", "t_mauer", "t_munition", "t_fallen"]:
		_rich()
		R.start(k)
		R.finish_now()
	T._check(R.tier_why(3).contains("Stufe 2"), "Reihe 4 braucht Labor Stufe 2")
	lab.level = 3
	T._check(R.state("t_wetter") == "open" and R.time_for("t_wetter") < float(DB.TIER_COST[3].time), "Laborstufe 3: Reihe 4 offen und schneller")
	var w = G.main.world
	var whp0: float = w.walls[0].max_hp if w.walls.size() > 0 else 0.0
	var bhp0: float = w.bunker_node.max_hp
	for k in ["t_wetter", "t_moertel", "t_panzer", "h_gurte", "w_saegen"]:
		_rich()
		var why := R.start(k)
		if why != "":
			print("Forschung %s: %s" % [k, why])
		R.finish_now()
	await T._wait(0.3)
	T._check(R.count() == 11, "elf Knoten erforscht (%d)" % R.count())
	T._check(w.walls.size() > 0 and w.walls[0].max_hp > whp0 * 1.12, "Mauern halten mehr aus (%.0f → %.0f)" % [whp0, w.walls[0].max_hp if w.walls.size() > 0 else 0.0])
	T._check(w.bunker_node.max_hp > bhp0 * 1.19, "Bunkerpanzer +20 %")
	T._check(P.cmd_bonus("carry") >= 0.08 and P.cmd_bonus("trap_dmg") >= 0.15, "Forschung über P.cmd_bonus (Rucksack, Fallen)")
	T._check(absf(R.prod_bonus("wood") - 0.10) < 0.001 and R.prod_bonus("metal") < 0.001, "Produktion Holz/Stein +10 %")
	T._check(absf(R.weather_k() - 0.5) < 0.001, "Wetterschutz halbiert Wetter-Nachteile")
	# Bildschirm
	G.main.screens.open("forschung", "tuerme")
	await T._wait(0.3)
	var nodes := _metas(G.main.screens._root, "research")
	T._check(nodes.size() == 11, "Baumansicht: 11 Knoten im Ast (%d)" % nodes.size())
	var tv = _find_class(G.main.screens._root, "TreeView")
	T._check(tv != null and tv.lines.size() >= 12, "Linien zwischen den Knoten (%d)" % (tv.lines.size() if tv != null else 0))
	_rich()
	G.main.screens.st["sel"] = "t_praezision"
	G.main.screens.refresh()
	await T._wait(0.2)
	var go := _metas(G.main.screens._root, "research_go")
	T._check(go.size() == 1 and not go[0].disabled, "Knopf „Erforschen“ bereit")
	if go.size() == 1:
		go[0].pressed.emit()
		await T._wait(0.2)
	T._check(R.current() == "t_praezision", "über den Bildschirm gestartet")
	G.main.screens.st["tab"] = 2
	G.main.screens.refresh()
	await T._wait(0.2)
	T._check(_metas(G.main.screens._root, "research").size() == 11, "Ast „Helden“ zeigt seine Knoten")
	G.main.screens.close()
	R.finish_now()


func _rich() -> void:
	for r in ["coins", "wood", "stone", "metal", "fuel", "cells"]:
		P.d.res[r] = P.cap(r)
	P.d.res.shards = 200
	P.d.res.gems = maxi(P.res("gems"), 2000)


func _metas(n: Node, key: String) -> Array:
	var out: Array = []
	if n == null:
		return out
	if n.has_meta(key):
		out.append(n)
	for ch in n.get_children():
		out.append_array(_metas(ch, key))
	return out


func _find_class(n: Node, cls: String):
	if n == null:
		return null
	if n.get_script() != null and String(n.get_script().get_global_name()) == cls:
		return n
	if n.get("lines") != null and n is Control and n.has_method("_draw") and cls == "TreeView":
		return n
	for ch in n.get_children():
		var r = _find_class(ch, cls)
		if r != null:
			return r
	return null


# ================================================================= Belagerung
## Baut einen geschlossenen Mauerring (Radius r Felder) in Bauart tier um den Bunker.
func _ring(r: int, level: int) -> Array:
	for b in P.d.buildings.duplicate():
		if String(b.key) == "wall" or String(b.key) == "tor":
			P.d.buildings.erase(b)
	var bk := P.bunker()
	var cx := int(bk.x) + 2
	var cy := int(bk.y) + 2
	var out: Array = []
	for i in range(-r, r + 1):
		for p in [[cx + i, cy - r], [cx + i, cy + r], [cx - r, cy + i], [cx + r, cy + i]]:
			if P.cells_free(int(p[0]), int(p[1]), 1, 1):
				out.append(P._add_building("wall", int(p[0]), int(p[1]), 0, level))
	P.buildings_changed.emit()
	return out


func _siege() -> void:
	await _fresh(8)
	var ring := _ring(13, 3)
	var bk := P.bunker()
	var cx := int(bk.x) + 2
	var cy := int(bk.y) + 2
	# ein Stück Holz auf der Südseite
	var weak: Dictionary = {}
	for b in ring:
		if int(b.y) == cy + 13 and int(b.x) == cx + 3:
			b.level = 1
			weak = b
	P.buildings_changed.emit()
	await T._wait(0.3)
	var w = G.main.world
	T._check(not weak.is_empty() and w.walls.size() >= ring.size() - 2, "Mauerring gebaut (%d Stück)" % w.walls.size())
	P.d.week.dirs = [0, 0]
	w.start_flood(true)
	w._queue.clear()
	await T._wait(0.2)
	var sg = w.horde.siege
	T._check(sg != null, "Belagerung läuft mit der Flut")
	if sg == null:
		return
	sg.breach.rebuild()
	var tgt = sg.breach_target(Vector2(0, -60))
	T._check(tgt != null and Siege.is_wall(tgt) and int(tgt.tier) == 0, "Brecher von Norden laufen zum Holzstück im Süden (%s)" % (str(Vector2i(tgt.x, tgt.y)) if tgt != null and Siege.is_wall(tgt) else str(tgt)))
	# angeschlagene Metallmauer im Norden ist jetzt die schwächste Stelle
	var north = null
	for seg in w.walls:
		if seg.y == cy - 13 and seg.x == cx:
			north = seg
	if north != null:
		north.hp = north.max_hp * 0.04
		sg.breach.rebuild()
		var tgt2 = sg.breach_target(Vector2(0, -60))
		T._check(tgt2 == north, "angeschlagene Mauer im Norden wird zum Ziel (%s)" % (str(Vector2i(tgt2.x, tgt2.y)) if tgt2 != null and Siege.is_wall(tgt2) else str(tgt2)))
		north.hp = north.max_hp
	# ein echter Brecher folgt dem Feld zur Holzmauer
	sg.breach.rebuild()
	for t in w.towers:
		t.active = false
	w.hero.global_position = Vector3(56, 0, 56)
	var tank = w.horde.spawn(D.E_BRUTE, Vector2(4, -50), 1.0, 1.0)
	var hit_weak := false
	for i in 400:
		await T._wait(0.25)
		if tank.st == 1 and tank.tgt != null and Siege.is_wall(tank.tgt) and int(tank.tgt.tier) == 0:
			hit_weak = true
			break
	T._check(hit_weak, "Brecher greift das Holzstück an (Ziel %s)" % (str(Vector2i(tank.tgt.x, tank.tgt.y)) if tank.tgt != null and Siege.is_wall(tank.tgt) else "keins"))
	w.horde.clear()
	# Leiter: Ring ganz aus Metall, ein Schleimling mit Leiter kommt von Norden und klettert über die Mauer
	w._finish(true)
	G.hud._close_modal()
	w.back_to_peace()
	weak.level = 3
	for b0 in P.d.buildings:
		b0.erase("dmg")
	P.buildings_changed.emit()
	await T._wait(0.3)
	w.start_flood(true)
	w._queue.clear()
	await T._wait(0.2)
	sg = w.horde.siege
	for t in w.towers:
		t.active = false
	w.hero.global_position = Vector3(56, 0, 56)
	var lad = w.horde.spawn(D.E_SLIME, Vector2(float((cx - 22) * 2 + 1), float((cy - 22 - 13) * 2 - 6)), 50.0, 1.0)
	lad.ladder = true
	var l0: int = sg.climbs
	var saw_climb := false
	var max_alt := 0.0
	for i in 300:
		await T._wait(0.2)
		if lad.ai_s == Siege.S_LADDER:
			saw_climb = true
			max_alt = maxf(max_alt, lad.alt)
		if sg.climbs > l0:
			break
	var inside: bool = lad.p.distance_to(w.bunker_node.mid) < 13 * 2.0
	T._check(saw_climb and max_alt > 1.5, "Leiter: klettert sichtbar hinauf (Höhe %.1f m)" % max_alt)
	T._check(sg.climbs > l0 and inside, "Leiter: landet innerhalb der Mauer (%s)" % str(lad.p))
	# Flieger meiden die Luftabwehr, wenn es einen Umweg gibt
	w.horde.clear()
	var aa := P._add_building("luftabwehr", cx - 1, cy - 9, 0, 1)
	aa.done_at = 0.0
	w._finish(true)
	G.hud._close_modal()
	w.back_to_peace()
	await T._wait(0.3)
	w.start_flood(true)
	w._queue.clear()
	await T._wait(0.3)
	sg = w.horde.siege
	T._check(sg.air != null and sg.air_cells > 20, "Flieger-Feld mit Luftabwehr (%d Felder)" % sg.air_cells)
	if sg.air != null:
		sg.air.rebuild()
		var aap := Vector2.ZERO
		for t in w.towers:
			if t.key == "aa":
				aap = t.pos2()
		var rr: float = 24.0 * w.tower_range_k()
		var start := Vector2(aap.x, -64.0)
		var straight := 0
		var q := start
		while q.distance_to(w.bunker_node.mid) > 3.0:
			q = q.move_toward(w.bunker_node.mid, 0.5)
			if q.distance_to(aap) < rr:
				straight += 1
		var via := 0
		q = start
		for i in 2000:
			if q.distance_to(w.bunker_node.mid) < 3.0:
				break
			q += sg.air.dir_at(q) * 0.5
			if q.distance_to(aap) < rr:
				via += 1
		T._check(via < straight * 0.7, "Flieger fliegen um die Luftabwehr herum (%d statt %d Schritte in Reichweite)" % [via, straight])
	w._finish(true)
	G.hud._close_modal()
	w.back_to_peace()
	await T._wait(0.2)


# ================================================================= Wetter
func _weather() -> void:
	await _fresh(5)
	var w = G.main.world
	FW.force = "regen"
	var fd: Dictionary = w.flood_preview(true)
	T._check(String(fd.get("weather", "")) == "regen" and not bool(fd.get("night", true)), "Vorhersage: Regen")
	G.hud._ask_flood()
	await T._wait(0.2)
	var box := _metas(G.hud.root, "weather")
	T._check(box.size() == 1 and String(box[0].get_meta("weather")) == "regen", "Wellen-Vorschau zeigt das Wetter")
	G.hud._close_modal()
	w.start_flood(true)
	w._queue.clear()
	await T._wait(0.2)
	T._check(absf(w.flood_rate_k - 0.9) < 0.001 and absf(w.horde.fire_mult - 0.7) < 0.001 and absf(w.flood_range_k - 1.0) < 0.001, "Regen: Türme langsamer, Feuer schwächer")
	var rate_now: float = w.tower_rate(Vector2(500, 500))
	T._check(rate_now < 0.95, "Feuertempo der Türme sinkt (%.2f)" % rate_now)
	w._finish(true)
	G.hud._close_modal()
	w.back_to_peace()
	T._check(absf(w.flood_rate_k - 1.0) < 0.001 and w.horde.fire_mult == 1.0, "nach der Flut wieder normal")
	FW.force = "nebel"
	w.start_flood(true)
	w._queue.clear()
	await T._wait(0.3)
	T._check(absf(w.flood_range_k - 0.8) < 0.001 and w.weather.fog_extra > 0.0, "Nebel: Reichweite -20 %, Nebel liegt über der Basis")
	w._finish(true)
	G.hud._close_modal()
	w.back_to_peace()
	FW.force = "nacht"
	var fn: Dictionary = w.flood_preview(true)
	FW.force = "klar"
	var fk: Dictionary = w.flood_preview(true)
	T._check(bool(fn.night) and absf(float(fn.hp) / float(fk.hp) - 1.1) < 0.01, "Nacht: Gegner +10 %% Leben (%.2f)" % (float(fn.hp) / float(fk.hp)))
	FW.force = "nacht"
	P.d.week.practice_day = -1
	P.d.res.coins = 1000
	var c0 := P.res("coins")
	w.start_flood(true)
	w._queue.clear()
	await T._wait(0.2)
	w._finish(true)
	T._check(w.result.has("extra") and P.res("coins") > c0 + int(w.result.get("coins", 0)), "Nacht: +10 %% Beute (%s)" % str(w.result.get("extra", {})))
	G.hud._close_modal()
	w.back_to_peace()
	FW.force = "klar"


# ================================================================= Rückblick und Reparatur
func _replay_and_repair() -> void:
	await _fresh(6)
	var w = G.main.world
	P.d.replays = []
	w.start_flood(false)
	w._queue.clear()
	await T._wait(0.3)
	T._check(w.replay != null, "Rückblick zeichnet auf")
	# Türme schießen: Schaden je Turm
	var shooter = null
	for t in w.towers:
		if t.key == "mg":
			shooter = t
			break
	if shooter != null:
		for i in 6:
			w.horde.spawn(D.E_SLIME, shooter.pos2() + Vector2(6, i - 3), 3.0, 0.0)
		await T._wait(2.0)
	var seg = w.walls[0]
	seg.hurt(1.0e9, true)
	var seg2 = w.walls[3]
	seg2.hp = seg2.max_hp * 0.4
	var victim = null
	for id in w.nodes:
		var s = w.nodes[id]
		if s.tower != null and s != shooter:
			victim = s
			break
	if victim != null:
		victim.hurt(1.0e9, true)
	await T._wait(0.2)
	w._finish(true)
	var rp: Dictionary = Replay.latest()
	T._check(not rp.is_empty() and String(rp.mode) == "flood" and not bool(rp.calc), "Rückblick der gespielten Flut gespeichert")
	var br := 0
	var lost := 0
	for wv in rp.get("waves", []):
		br += (wv.br as Array).size()
		lost += (wv.lost as Array).size()
	T._check(br >= 1 and lost >= 1, "Mauerbruch und verlorenes Gebäude erfasst (%d, %d)" % [br, lost])
	var tl: Array = rp.get("towers", [])
	T._check(tl.size() > 0 and int(tl[0][5]) > 0, "Türme nach Schaden sortiert (bester: %s %d)" % [String(tl[0][0]) if tl.size() > 0 else "-", int(tl[0][5]) if tl.size() > 0 else 0])
	T._check((rp.map.w as Array).size() > 10 and (rp.map.b as Array).size() > 3, "kleine Karte der Basis")
	G.hud._close_modal()
	w.back_to_peace()
	await T._wait(0.3)
	# Mauer-Schäden bleiben, sind sichtbar, „Alle reparieren“
	var bseg := P.get_building(int(seg.id))
	T._check(float(bseg.get("dmg", 0.0)) > 0.8 and float(P.get_building(int(seg2.id)).get("dmg", 0.0)) > 0.5, "Mauern behalten ihren Schaden (%.2f)" % float(bseg.get("dmg", 0.0)))
	var dmg_seg = null
	for s3 in w.walls:
		if s3.id == seg.id:
			dmg_seg = s3
	T._check(dmg_seg != null and dmg_seg.alive and dmg_seg.hp < dmg_seg.max_hp * 0.2, "zerstörtes Stück steht als Trümmer")
	w.life.update_wall_damage()
	T._check(w.life.walls_damaged >= 2, "Schaden sichtbar (%d Stücke)" % w.life.walls_damaged)
	var q := BState.repair_quote()
	T._check(int(q.walls) >= 2 and not (q.cost as Dictionary).is_empty(), "Reparatur kostet etwas (%s)" % str(q.cost))
	T._check(w.life.repair_all() == "", "alle reparieren")
	await T._wait(0.2)
	var left := 0
	for b in P.d.buildings:
		if b.has("dmg"):
			left += 1
	var full := true
	for s4 in w.walls:
		if s4.hp < s4.max_hp - 0.5 and not s4.site:
			full = false
	T._check(left == 0 and full, "alles heil (%d übrig)" % left)
	# Rückblick der verpassten Flut (Berechnung)
	P.d.week.flood_done = false
	P._auto_flood()
	var ra: Dictionary = Replay.latest()
	T._check(String(ra.get("mode", "")) == "auto" and bool(ra.get("calc", false)) and (ra.waves as Array).size() == int(D.flood_def(int(P.d.week.number), P.bunker_level()).waves), "verpasste Flut: Rückblick aus der Berechnung (%d Wellen)" % (ra.waves as Array).size())
	T._check((ra.get("towers", []) as Array).size() > 0, "verpasste Flut: Türme mit Schaden")
	T._check(Replay.unseen() >= 1, "neuer Rückblick ist ungesehen")
	G.main.screens.open("rueckblick")
	await T._wait(0.3)
	var mm = _find_mm(G.main.screens._root)
	T._check(mm != null and mm.rec.has("map"), "Rückblick-Bildschirm mit Karte")
	G.main.screens.st["wave"] = 1
	G.main.screens.refresh()
	await T._wait(0.2)
	G.main.screens.close()
	T._check(Replay.unseen() == 0, "angesehen")


func _find_mm(n: Node):
	if n == null:
		return null
	if n.get("rec") != null and n.get("wave") != null:
		return n
	for ch in n.get_children():
		var r = _find_mm(ch)
		if r != null:
			return r
	return null


# ================================================================= Layouts
func _layouts() -> void:
	await _fresh(6)
	var w = G.main.world
	var code := LayoutCode.encode()
	var n := 0
	for b in P.d.buildings:
		if LayoutCode.KEYS.has(String(b.key)):
			n += 1
	print("Layout-Code: %d Zeichen für %d Gebäude" % [code.length(), n])
	var dc := LayoutCode.decode(code)
	T._check(code.begins_with("RW1-") and bool(dc.ok) and (dc.entries as Array).size() == n, "Layout-Code lesbar (%d Einträge)" % (dc.get("entries", []) as Array).size())
	T._check(code.length() < 400, "Code ist kurz (%d Zeichen)" % code.length())
	var bad := code.substr(0, code.length() - 2) + ("AA" if not code.ends_with("AA") else "BB")
	T._check(not bool(LayoutCode.decode(bad).ok), "beschädigter Code wird erkannt")
	T._check(not bool(LayoutCode.decode("Hallo Welt").ok), "fremder Text wird abgelehnt")
	# Turm verschieben, Code des alten Aufbaus einfügen, laden: alles wieder wie vorher
	var mg: Dictionary = {}
	for b in P.d.buildings:
		if String(b.key) == "mg":
			mg = b
			break
	var x0 := int(mg.x)
	var y0 := int(mg.y)
	var c := int(D.GRID_MAX / 2)
	var moved := false
	for dx in range(-8, 9):
		if P.move(int(mg.id), c + dx, c + 7, 0):
			moved = true
			break
	T._check(moved, "Turm verschoben")
	var res := LayoutCode.paste(code, 1)
	T._check(bool(res.ok) and int(res.placed) == n, "Code passt auf die eigene Basis (%s)" % String(res.why))
	T._check(P.load_layout(1) and int(mg.x) == x0 and int(mg.y) == y0, "eingefügter Aufbau geladen")
	# Layout-Test: Platz 2 mit verschobenem Turm, Flut ohne Verlust, danach eigener Aufbau zurück
	for dx in range(-8, 9):
		if P.move(int(mg.id), c + dx, c + 7, 0):
			break
	P.save_layout(2)
	var xt := int(mg.x)
	P.move(int(mg.id), x0, y0, 0)
	var coins0 := P.res("coins")
	var pday := int(P.d.week.practice_day)
	await T._wait(0.2)
	T._check(LayoutCode.test_start(w, 2) == "", "Layout-Test startet")
	T._check(w.layout_test and w.mode == "practice" and int(mg.x) == xt, "Aufbau aus Platz 3 steht während des Tests")
	T._check(int(w.flood.total) == int(D.flood_def(int(P.d.week.number), P.bunker_level()).total), "Stärke der echten Flut")
	w._queue.clear()
	await T._wait(0.2)
	w.walls[0].hurt(1.0e9, true)
	w._finish(false)
	T._check(bool(w.result.get("test", false)) and P.res("coins") >= coins0 and int(P.d.week.practice_day) == pday, "ohne Verlust, ohne Belohnung, Übung bleibt")
	G.hud._close_modal()
	w.back_to_peace()
	await T._wait(0.2)
	T._check(int(mg.x) == x0 and int(mg.y) == y0 and not P.d.layout_test.has("backup"), "eigener Aufbau wieder da")
	var dmg_any := false
	for b in P.d.buildings:
		if String(b.key) == "wall" and b.has("dmg"):
			dmg_any = true
	T._check(not dmg_any, "Layout-Test hinterlässt keinen Mauerschaden")
	T._check(Replay.latest().get("mode", "") == "test", "Rückblick des Tests")
	# Dialog
	BasisUI.layouts_dialog(G.hud, "", code)
	await T._wait(0.1)
	T._check(_metas(G.hud.root, "layout_code").size() == 1, "Dialog „Aufbauten“")
	G.hud._close_modal()


# ================================================================= Funde beim Räumen
func _finds() -> void:
	await _fresh(4)
	var w = G.main.world
	var c := int(D.GRID_MAX / 2)
	var spots: Array = []
	for y in range(c - 10, c + 10):
		for x in range(c - 10, c + 10):
			if spots.size() < 3 and P.cells_free(x, y, 1, 1) and P.cells_free(x - 1, y - 1, 3, 3):
				spots.append(Vector2i(x, y))
	T._check(spots.size() == 3, "freie Felder für Hindernisse")
	if spots.size() < 3:
		return
	var kinds := ["gems", "chest", "bp"]
	var obs: Array = []
	for i in 3:
		var b := P._add_building("hind_busch", spots[i].x, spots[i].y, 0, 1)
		b["find_roll"] = true
		b["find"] = kinds[i]
		obs.append(b)
	P.buildings_changed.emit()
	await T._wait(0.8)
	w.life._update_glints()
	T._check(w.life.glint_count() >= 3, "Hindernisse mit Fund glitzern (%d)" % w.life.glint_count())
	var g0 := P.gems()
	var ch0 := P.chest_count()
	P.d.bp_frags = DB.BP_FRAGS - 1
	var bp0 := (P.d.blueprints as Dictionary).size()
	var sh0 := P.res("shards")
	var f0 := P.stat("finds")
	for b in obs:
		P.clear_obstacle(int(b.id))
	P.speed_up_builds(1.0e9)
	await T._wait(0.5)
	T._check(P.stat("finds") == f0 + 3, "drei Funde (%d)" % (P.stat("finds") - f0))
	T._check(P.gems() >= g0 + 3 + int(DB.FIND_GEMS[0]), "Juwelen gefunden (+%d)" % (P.gems() - g0))
	T._check(P.chest_count() == ch0 + 1, "Fundkiste gefunden")
	T._check((P.d.blueprints as Dictionary).size() == bp0 + 1 or P.res("shards") >= sh0 + 2, "Bauplan-Splitter ergeben einen Bauplan")
	w.life._update_glints()
	T._check(w.life.glint_count() == 0, "kein Glitzer mehr")
	# Wurf beim Nachwachsen
	var nb := P._add_building("hind_stein", spots[0].x, spots[0].y, 0, 1)
	BState.roll_find(nb)
	T._check(nb.has("find_roll"), "neues Hindernis bekommt seinen Fund-Wurf")
	P.d.buildings.erase(nb)
	P.buildings_changed.emit()


# ================================================================= Verletzte und Wasser
func _injured_and_water() -> void:
	await _fresh(6)
	var w = G.main.world
	await T._wait(1.0)
	P.d.injured = {}
	var n := BState.injuries_after(false, 0.0, 0, 0)
	T._check(n >= 2, "verlorene Flut: Bewohner verletzt (%d)" % n)
	w.life._update_injured()
	var hurt: Array = []
	for npc in w.npc_board.npcs:
		if npc.injured:
			hurt.append(npc)
	T._check(hurt.size() == n, "Verletzte erkannt (%d)" % hurt.size())
	if hurt.size() > 0:
		var h0 = hurt[0]
		T._check(h0.h.find_child("Verband", true, false) != null, "Verband am Kopf")
		var ct: Dictionary = w.life.care_task(w.npc_board, h0)
		T._check(not ct.is_empty() and String(ct.kind) == "care", "Verletzte gehen zum Verarzten")
		var left0 := BState.heal_left(String(h0.name))
		BState.cared(String(h0.name))
		T._check(BState.heal_left(String(h0.name)) < left0 - 100.0, "Verarzten verkürzt die Heilzeit")
		# Lauftempo: ein Weg dauert länger
		h0.give({"kind": "test", "steps": [{"at": h0.pos + Vector2(6, 0), "text": "Test"}]})
		var p0: Vector2 = h0.pos
		await T._wait(1.0)
		var dist: float = h0.pos.distance_to(p0)
		T._check(dist < 2.2 * 1.0 * 0.8 + 0.3, "Verletzte gehen langsamer (%.2f m in 1 s)" % dist)
	T._check(BState.injuries_after(true, 1.0, 0, 0) == 0, "leichte Flut: niemand verletzt")
	var hard := BState.injuries_after(true, 0.3, 0, 0)
	T._check(hard >= 1, "harte Flut: Verletzte (%d)" % hard)
	P.skip_time(DB.INJURY_TIME + 10.0)
	w.life._update_injured()
	T._check(BState.injured_now().is_empty() and w.life.bandages == 0, "nach der Heilzeit gesund")
	# Wasser: Tümpel, Bach-Ufer, Brandung – Spritzer beim Laufen
	T._check(w.life.wet_at(Nature.POND) == 2 and w.life.wet_at(Vector2.ZERO) == 0 and w.life.wet_at(Nature.BRIDGE) == 0, "Tümpel nass, Basis und Brücke trocken")
	T._check(not w.field.is_solid(Nature.POND), "Tümpel ist begehbar")
	var brook_edge := false
	for i in 80:
		var q := Vector2(50.0 + i * 0.1, -31.0)
		if w.life.wet_at(q) == 2 and not w.field.is_solid(q):
			brook_edge = true
			break
	T._check(brook_edge, "Bach-Ufer: nass und begehbar")
	var s0: int = w.life.splashes
	w.hero.global_position = Vector3(Nature.POND.x, 0, Nature.POND.y)
	w.life._on_step(true)
	T._check(w.life.splashes == s0 + 1, "Spritzer im Tümpel")
	# echter Lauf durch den Tümpel
	var s1: int = w.life.splashes
	w.hero.global_position = Vector3(Nature.POND.x - 2.5, 0, Nature.POND.y)
	for i in 30:
		G.touch_move = Vector2(1, 0)
		await T._wait(0.1)
	G.touch_move = Vector2.ZERO
	T._check(w.life.splashes > s1, "beim Durchlaufen spritzt es (%d)" % (w.life.splashes - s1))
	w.hero.global_position = Vector3(w.respawn_point().x, 0, w.respawn_point().y)


# ================================================================= Mitteilungen, Bewertung, Vibration
func _mobile() -> void:
	await _fresh(4)
	var w = G.main.world
	P.d.notify = {"on": true, "build": true, "flood": true, "gift": true, "research": true}
	var c := int(D.GRID_MAX / 2)
	var b := P.place("garage", c - 12, c - 12)
	if b.is_empty():
		b = P.place("lager", c + 8, c - 12)
	P.d.week.start_day = P.day_index()
	P.d.week.flood_done = false
	var pl := Notify.plan()
	var kinds := {}
	for e in pl:
		kinds[String(e.kind)] = true
	var want_build: bool = not b.is_empty() and float(b.done_at) > P.now() + 30.0
	T._check(kinds.has("gift") and kinds.has("flood") and (kinds.has("build") or not want_build), "Mitteilungen geplant: %s" % ", ".join(kinds.keys()))
	P.d.notify.build = false
	var k2 := {}
	for e in Notify.plan():
		k2[String(e.kind)] = true
	T._check(not k2.has("build"), "Schalter „Bau fertig“ wirkt")
	P.d.notify.on = false
	T._check(Notify.plan().is_empty(), "Mitteilungen aus: nichts geplant")
	P.d.notify.on = true
	Notify.on_app(Node.NOTIFICATION_APPLICATION_PAUSED)
	T._check(not Notify.available() and Notify.pending.size() > 0, "PC/Web: still, aber vorgemerkt (%d)" % Notify.pending.size())
	Notify.on_app(Node.NOTIFICATION_APPLICATION_RESUMED)
	T._check(Notify.pending.is_empty(), "zurück im Spiel: gelöscht")
	G.main.screens.open("settings")
	await T._wait(0.3)
	T._check(_metas(G.main.screens._root, "notify").size() >= 4, "Optionen: Schalter für Mitteilungen")
	G.main.screens.close()
	# Bewertungs-Hinweis nach dem ersten Flut-Sieg
	P.d.rate = {"asked": 0, "answer": "", "pending": false}
	P.d.week.start_day = P.day_index() - 6
	P.d.week.flood_done = false
	w.start_flood(false)
	w._queue.clear()
	await T._wait(0.2)
	w._finish(true)
	T._check(bool(P.d.rate.pending), "erster Flut-Sieg: Bewertungs-Hinweis vorgemerkt")
	G.hud._close_modal()
	w.back_to_peace()
	BasisUI.ask_rating(G.hud)
	await T._wait(0.1)
	T._check(G.hud.modal_open() and not bool(P.d.rate.pending) and int(P.d.rate.asked) == 1, "„Gefällt dir Rustwall?“ erscheint einmal")
	G.hud._close_modal()
	var r0 := Notify.reviews
	Notify.request_review()
	T._check(Notify.reviews == r0 + 1, "Store-Bewertung angefragt (am PC ohne Wirkung)")
	# Vibration bei Bau fertig, Kiste und Stufe
	var v0: int = G.vibrations
	var nb := P.place("laterne", c - 2, c - 9)
	P.speed_up_builds(1.0e9)
	await T._wait(0.6)
	var v1: int = G.vibrations
	if G.hud != null and G.hud.guide != null:
		G.hud.guide._update()                         # Ausgangswert der Kisten merken (hud_guide.gd prüft alle 0,25 s)
	P.d.stats.chests = int(P.d.stats.get("chests", 0)) + 1
	if G.hud != null and G.hud.guide != null:
		G.hud.guide._update()
	await T._wait(0.3)
	var v2: int = G.vibrations
	P.add_xp(1.0e5)
	await T._wait(0.3)
	var v3: int = G.vibrations
	T._check(nb.is_empty() or v1 > v0, "Vibration: Bau fertig")
	T._check(v2 > v1, "Vibration: Kiste")
	T._check(v3 > v2, "Vibration: Stufenaufstieg")
