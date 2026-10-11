extends RefCounted
## Prüfungen für Paket 2 (Kluge Bewohner): Wegegitter mit Toren, Beobachtung (kein Bewohner in gesperrten Feldern,
## keiner hängt fest), Arbeit an jedem Produktionsgebäude, Baumeister an jeder Baustelle in 10 s, Alarm über das Tor
## in den Bunker, Reparatur nach der Flut durch Handwerker, Rechenzeit.
## Aufruf aus tests.gd (--selftest, gekürzt) oder allein mit --autotest=npc (10 Minuten Beobachtung im Zeitraffer).

const D = preload("res://src/data.gd")
const NavGrid = preload("res://src/nav_grid.gd")

var T: Node                      # tests.gd (für _check und _wait)


func _init(tests: Node) -> void:
	T = tests


func run() -> void:
	await _alarm_and_repair()
	await observe(75.0)


## Allein: --autotest=npc [--limit_npc=600]
func autotest() -> void:
	var r: Dictionary = await observe(float(G.arg("minutes", "10")) * 60.0)
	var r2: Dictionary = await _alarm_and_repair()
	print("RESULT mode=npc win=%s t=%.0fs npcs=%d blocked=%d stuck=%d warps=%d prod=%d/%d sites=%d/%d site_max=%.1fs logic_avg=%.3fms logic_max=%.2fms alarm_hidden=%d/%d gate=%d repair=%s" % [
		r.ok and r2.ok, r.t, r.npcs, r.blocked, r.stuck, r.warps, r.prod_ok, r.prod, r.sites_ok, r.sites, r.site_max, r.logic_avg, r.logic_max,
		r2.hidden, r2.need, r2.gate, r2.repair])


# ---------------------------------------------------------------- Testbasen
func _free_cell(w: int, h: int, c: int, start_r := 3) -> Vector2i:
	for r in range(start_r, 22):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				# ein Feld Luft rundherum, damit Wege bleiben
				if P.cells_free(c + dx - 1, c + dy - 1, w + 2, h + 2):
					return Vector2i(c + dx, c + dy)
	return Vector2i(-1, -1)


## Bunker 10 (13 Bewohner) mit allen Produktionsgebäuden, Lager, Blumen, Wachturm und Mauerring mit Toren.
func _prod_base() -> void:
	P.debug_setup(10)
	var c := int(D.GRID_MAX / 2)
	for key in ["saege", "steinbruch", "presse", "raffinerie", "generator", "saege", "lager", "quartier", "werkstatt", "training", "funkturm", "blumen", "blumen"]:
		if P.count(key) >= P.max_count(key):
			continue
		var s := P.size_of(key, 0)
		var at := _free_cell(s.x, s.y, c - int(s.x / 2), 4)
		if at.x >= 0:
			P._add_building(key, at.x, at.y, 0, 1)
	# zwei Tore in den Ring der Testbasis
	var n := 0
	for b in P.d.buildings.duplicate():
		if b.key == "wall" and n < 2 and (int(b.x) == c and (int(b.y) == c - 10 or int(b.y) == c + 10)):
			P.wall_to_gate(int(b.id), true)
			n += 1
	P.buildings_changed.emit()


## Eine Baustelle, die lange dauert (Bauzeit läuft in echter Zeit).
func _add_site(key: String) -> int:
	var c := int(D.GRID_MAX / 2)
	var s := P.size_of(key, 0)
	var at := _free_cell(s.x, s.y, c, 5)
	if at.x < 0:
		return -1
	var b := P._add_building(key, at.x, at.y, 0, 1)
	b.t0 = P.now()
	b.done_at = P.now() + 3600.0
	P.buildings_changed.emit()
	return int(b.id)


# ---------------------------------------------------------------- Beobachtung
## Beobachtet die Bewohner `secs` Sekunden Spielzeit; prüft je Sekunde gesperrte Felder und Stillstand.
func observe(secs: float) -> Dictionary:
	_prod_base()
	G.main.goto_base()
	var w = G.main.world
	await T._wait(0.5)
	var nb = w.npc_board
	var last := {}
	var still := {}
	var blocked := 0
	var stuck := 0
	var sites_ok := 0
	var sites_n := 0
	var site_max := 0.0
	var site_ids: Array = []
	var logic_sum := 0.0
	var logic_n := 0
	var logic_max := 0.0
	var t0: float = w.time
	var next_site := 5.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var sec := 0
	while w.time - t0 < secs:
		await T._wait(1.0)
		sec += 1
		logic_sum += nb.logic_ms
		logic_n += 1
		for n in nb.npcs:
			if n.hidden:
				continue
			if w.field.blocks_player(n.pos):
				blocked += 1
				print("NPC IM GESPERRTEN FELD: %s (%s) bei %s, Zustand %s" % [n.name, n.job, str(n.pos), n.state])
			var lp: Vector2 = last.get(n, Vector2.INF)
			var moved: bool = lp == Vector2.INF or lp.distance_to(n.pos) > 0.05
			last[n] = n.pos
			if moved or n.is_pausing():
				still[n] = 0
			else:
				still[n] = int(still.get(n, 0)) + 1
				if int(still[n]) > 2:
					stuck += 1
					print("NPC HÄNGT: %s (%s) bei %s, Zustand %s, Aufgabe %s" % [n.name, n.job, str(n.pos), n.state, n.doing()])
					still[n] = 0
		# alle 60 s eine neue Baustelle; der Held läuft ab und zu woanders hin (Ausweichen)
		if w.time - t0 > next_site:
			next_site += 60.0
			var id := _add_site(["mg", "kanone", "mg", "tesla", "wachturm"][site_ids.size() % 5])
			if id >= 0:
				site_ids.append([id, w.time])
		if sec % 15 == 0 and w.hero != null:
			var q: Vector2 = nb.nav.free_near(Vector2(rng.randf_range(-16, 16), rng.randf_range(-16, 16)))
			w.hero.global_position = Vector3(q.x, 0, q.y)
	# Rechenzeit: über viele Bilder gemittelt
	for i in 120:
		await w.get_tree().physics_frame
		logic_sum += nb.logic_ms
		logic_n += 1
		logic_max = maxf(logic_max, nb.logic_ms)
	for e in site_ids:
		var info = nb.sites.get(int(e[0]))
		if info == null:
			continue
		sites_n += 1
		var dt: float = float(info.served) - float(info.seen) if float(info.served) >= 0.0 else 999.0
		site_max = maxf(site_max, dt)
		if dt <= 10.0:
			sites_ok += 1
	var prod := 0
	var prod_ok := 0
	for id in w.nodes:
		var s = w.nodes[id]
		if D.BUILDINGS[s.key].has("prod") and not s.constructing:
			prod += 1
			if nb.work_seen.has(int(id)):
				prod_ok += 1
			else:
				print("NIEMAND ARBEITET AN: %s (%d)" % [s.key, id])
	# Antippen: Schild mit Name, Beruf, Tätigkeit
	var tapped := false
	var cam: Camera3D = w.get_viewport().get_camera_3d()
	for n in nb.npcs:
		if not n.hidden and cam != null and not cam.is_position_behind(n.h.global_position):
			var sp := cam.unproject_position(n.h.global_position + Vector3(0, 1.1, 0))
			if w.get_viewport().get_visible_rect().has_point(sp) and nb.tap(sp):
				for m in nb.npcs:
					if m._sign != null and m._sign.visible and m._sign.text.contains(m.name):
						tapped = true
				break
	T._check(tapped, "Antippen zeigt ein Schild mit Name und Tätigkeit")
	var warps := 0
	var plain := 0
	for n in nb.npcs:
		warps += n.warps
		if n.hero_key == "":
			plain += 1
	var avg := logic_sum / maxf(logic_n, 1.0)
	T._check(plain == 13, "Bunker 10: 13 Bewohner (%d)" % plain)
	T._check(blocked == 0, "kein Bewohner in gesperrtem Feld (%d Funde)" % blocked)
	T._check(stuck == 0, "kein Bewohner länger als 2 s ohne Fortschritt (%d Funde)" % stuck)
	T._check(prod_ok == prod, "an jedem Produktionsgebäude arbeitet jemand (%d/%d)" % [prod_ok, prod])
	T._check(sites_ok == sites_n and sites_n > 0, "Baumeister an jeder Baustelle in 10 s (%d/%d, längste %.1f s)" % [sites_ok, sites_n, site_max])
	T._check(avg < 0.6, "Bewohner-Logik im Mittel unter 0,6 ms je Bild (%.3f ms, Spitze %.2f ms)" % [avg, logic_max])
	print("NPC-Beobachtung: %d s, %d Figuren, Wegsuchen %d, versetzt %d, Logik %.3f ms (Spitze %.2f ms)" % [int(w.time - t0), nb.npcs.size(), nb.nav.searches, warps, avg, logic_max])
	return {"ok": blocked == 0 and stuck == 0 and prod_ok == prod and sites_ok == sites_n and avg < 0.6 and plain == 13,
		"t": w.time - t0, "npcs": nb.npcs.size(), "blocked": blocked, "stuck": stuck, "warps": warps, "prod": prod, "prod_ok": prod_ok,
		"sites": sites_n, "sites_ok": sites_ok, "site_max": site_max, "logic_avg": avg, "logic_max": logic_max}


# ---------------------------------------------------------------- Alarm und Reparatur
## Mauerring mit einem Tor um den Bunker; Bewohner stehen teils draußen. Bei Alarm müssen alle Nicht-Wachen
## nach 15 s im Bunker sein, die von draußen durch das Tor. Danach: Reparatur statt Sofortheilung.
func _alarm_and_repair() -> Dictionary:
	P.new_game()
	P.no_save = true
	for b0 in P.d.buildings.duplicate():
		if b0.key == "wall" or b0.key == "tor":
			P.d.buildings.erase(b0)
	P.bunker().level = 6
	var c := int(D.GRID_MAX / 2)
	var r := 7
	for i in range(-r, r + 1):
		for p in [[c + i, c - r], [c + i, c + r], [c - r, c + i], [c + r, c + i]]:
			if P.cells_free(int(p[0]), int(p[1]), 1, 1):
				P._add_building("wall", int(p[0]), int(p[1]), 0, 1)
	for key in ["saege", "lager"]:
		var s := P.size_of(key, 0)
		var at := _free_cell(s.x, s.y, c - 1, 3)
		if at.x >= 0:
			P._add_building(key, at.x, at.y, 0, 1)
	var gate := {}
	for b in P.d.buildings:
		if b.key == "wall" and int(b.y) == c + r and int(b.x) == c:
			gate = P.wall_to_gate(int(b.id), true)
	G.main.goto_base()
	var w = G.main.world
	await T._wait(0.5)
	var nb = w.npc_board
	var lim: float = (r - 0.5) * D.CELL
	var home: Vector2 = w.bunker_node.mid
	# die Hälfte der Bewohner nach draußen stellen (rundherum)
	var outside: Array = []
	var k := 0
	for n in nb.npcs:
		if k % 2 == 0:
			var a := k * 1.3
			var q: Vector2 = nb.nav.free_near(home + Vector2(cos(a), sin(a)) * (lim + 4.0))
			n.show_at(q)
			n.task = {}
			n.state = "idle"
			outside.append(n)
		k += 1
	await T._wait(0.3)
	w.start_flood(true)
	var t0: float = w.time
	await T._wait(15.0)
	var need := 0
	var hidden := 0
	var through := 0
	var out_n := 0
	for n in nb.npcs:
		if n.job == "wache":
			continue
		need += 1
		if n.hidden:
			hidden += 1
		else:
			print("NICHT IM BUNKER: %s (%s) bei %s, %s" % [n.name, n.job, str(n.pos), n.doing()])
		if outside.has(n):
			out_n += 1
			if n.used_gate:
				through += 1
			else:
				print("NICHT DURCHS TOR: %s versetzt=%d" % [n.name, n.warps])
	T._check(not gate.is_empty() and hidden == need and need > 0, "Alarm: nach 15 s alle Nicht-Wachen im Bunker (%d/%d)" % [hidden, need])
	T._check(through == out_n and out_n > 0, "Alarm: Bewohner von draußen kamen durch das Tor (%d/%d)" % [through, out_n])
	# Sieg: Gebäude beschädigen bzw. zerstören, dann Frieden
	var saege = null
	var lager = null
	for id in w.nodes:
		if w.nodes[id].key == "saege":
			saege = w.nodes[id]
		elif w.nodes[id].key == "lager":
			lager = w.nodes[id]
	if saege != null:
		saege.hp = saege.max_hp * 0.5
	if lager != null:
		lager._destroy()
	w.bunker_node.hp = w.bunker_node.max_hp * 0.4
	w.horde.clear()
	w._finish(true)
	await T._wait(1.5)
	w.back_to_peace()
	await T._wait(0.2)
	var bunker_full: bool = w.bunker_node.hp >= w.bunker_node.max_hp
	var s_hp0: float = saege.hp / saege.max_hp if saege != null else 0.0
	var l_hp0: float = lager.hp / lager.max_hp if lager != null and lager.alive else 0.0
	var visible := 0
	for n in nb.npcs:
		if not n.hidden:
			visible += 1
	T._check(visible == nb.npcs.size(), "nach der Flut sind alle wieder draußen (%d/%d)" % [visible, nb.npcs.size()])
	T._check(bunker_full, "Bunker nach der Flut sofort voll")
	T._check(absf(s_hp0 - 0.5) < 0.02, "beschädigtes Gebäude behält seinen Schaden (%.2f)" % s_hp0)
	T._check(absf(l_hp0 - D.NPC_RUBBLE_HP) < 0.02, "zerstörtes Gebäude steht mit 10 %% wieder (%.2f)" % l_hp0)
	await T._wait(2.0)
	var hands := 0
	for n in nb.npcs:
		if n.job == "hand":
			hands += 1
	T._check(hands >= 2, "mindestens zwei Handwerker nach der Flut (%d)" % hands)
	await T._wait(25.0)
	var s_hp1: float = saege.hp / saege.max_hp if saege != null else 0.0
	var l_hp1: float = lager.hp / lager.max_hp if lager != null else 0.0
	var repaired := s_hp1 > s_hp0 + 0.05 or l_hp1 > l_hp0 + 0.05
	T._check(repaired, "Handwerker reparieren (Sägewerk %.2f -> %.2f, Lager %.2f -> %.2f)" % [s_hp0, s_hp1, l_hp0, l_hp1])
	return {"ok": hidden == need and through == out_n and bunker_full and repaired and hands >= 2, "hidden": hidden, "need": need, "gate": through,
		"repair": "%.2f->%.2f/%.2f->%.2f" % [s_hp0, s_hp1, l_hp0, l_hp1]}
