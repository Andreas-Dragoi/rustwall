extends RefCounted
## Prüfungen für Paket 3 (Expedition neu) und Paket 4 (Außenbasen): Sperren und Durchgänge, Reserve der Landezone,
## Teilzahlungen, fester Ort, Depot, halber Rucksack, Vorteile, Stufen 2–5, Lieferung, Belagerung, Weltkarte.
## Aufruf aus tests.gd (--selftest).

const D = preload("res://src/data.gd")

var T: Node                      # tests.gd (für _check und _wait)


func _init(tests: Node) -> void:
	T = tests


func run() -> void:
	_rules()
	await _world()
	await _relief()
	await _screens()


func _fresh() -> void:
	P.new_game()
	P.no_save = true
	P.d.level = 60
	for i in D.AREAS.size():
		for dd in 3:
			P.d.areas.boss[i][dd] = true
	P.d.outposts = {}
	P._ensure_fields()


# ---------------------------------------------------------------- reine Regeln (Paket 4)
func _rules() -> void:
	_fresh()
	T._check(D.OUTPOSTS.size() == D.AREAS.size(), "OUTPOSTS: je Gebiet einer in data.gd")
	for a in D.AREAS:
		T._check(D.OUTPOSTS.has(String(a.key)) and D.OUTPOSTS[String(a.key)].effects.size() >= 2, "Vorteile für %s" % a.key)
	# Holzproduktion mit und ohne Außenbasis
	P.add_many({"coins": 4000, "wood": 1400})
	var c := int(D.GRID_MAX / 2)
	var sg := P.place("saege", c + 6, c + 2)
	P.speed_up_builds(1.0e9)
	var r0 := P.prod_rate(sg)
	P.outpost_set_level("gruental", 1)
	var r1 := P.prod_rate(sg)
	T._check(absf(r1 / r0 - 1.10) < 0.001, "Holzrate +10 %% mit Holzfällerlager (%.3f)" % (r1 / r0))
	P.outpost_set_level("gruental", 5)
	T._check(absf(P.prod_rate(sg) / r0 - 1.20) < 0.001, "Holzrate +20 % auf Stufe 5")
	# Treibstoffpreis
	var f0 := P.fuel_cost(6)
	P.outpost_set_level("staub", 1)
	var f1 := P.fuel_cost(6)
	T._check(f1 < f0 and f1 == int(ceil(float(D.AREAS[6].fuel) * 0.9)), "Treibstoff −10 %% (%d → %d)" % [f0, f1])
	var vs0: float = float(D.VEHICLES[D.VEHICLE_ORDER[0]].speed)
	T._check(absf(P.vehicle_stats(D.VEHICLE_ORDER[0]).speed - vs0 * (1.0 + 0.06 * int(P.d.vehicles[D.VEHICLE_ORDER[0]].motor)) * (1.0 + P.cmd_bonus("vehicle")) * 1.04) < 0.001, "Fahrzeuge 4 % schneller")
	# Mauerleben
	var w0 := P.outpost_bonus("wall_hp")
	P.outpost_set_level("frost", 1)
	T._check(absf(P.outpost_bonus("wall_hp") - w0 - 0.10) < 0.001, "Mauern und Tore +10 % Leben")
	# Boss-Schaden
	P.outpost_set_level("krater", 1)
	T._check(absf(P.boss_dmg_mult() - 1.08) < 0.001, "Schaden gegen Bosse +8 %")
	# Rucksack +5 % je Außenbasis (höchstens +35 %)
	var n := P.outpost_count()
	T._check(n == 4, "vier Außenbasen stehen (%d)" % n)
	var hk := String(P.d.hero_sel)
	var cap4 := P.backpack_cap(hk, "")
	P.outpost_set_level("forst", 1)
	T._check(absf(P.backpack_cap(hk, "") / cap4 - 1.25 / 1.20) < 0.001, "Rucksack +5 % je Außenbasis")
	# Lieferung nach Tageswechsel (höchstens drei Tage)
	P.d.pickups = []
	P.outpost("gruental").last_delivery = P.day_index() - 1
	P.outpost("kueste").level = 0
	P.outpost_deliveries()
	var got := {}
	for p in P.d.pickups:
		if String(p.kind) == "outpost_gruental":
			got = p.bundle
	T._check(int(got.get("wood", 0)) == 300 and String(P.d.pickups[0].at) == "lager", "Lieferung: 300 Holz am Lager (Stufe 5)")
	P.outpost("gruental").last_delivery = P.day_index() - 6
	P.outpost_deliveries()
	for p in P.d.pickups:
		if String(p.kind) == "outpost_gruental":
			got = p.bundle
	T._check(int(got.get("wood", 0)) == 900, "höchstens drei Tage sammeln sich an (%d)" % int(got.get("wood", 0)))
	var wood := P.res("wood")
	P.d.res.wood = 0
	for p in P.d.pickups.duplicate():
		if String(p.kind) == "outpost_gruental":
			P.claim_pickup(int(p.id))
	T._check(P.res("wood") == mini(900, P.cap("wood")), "Lieferung eingesammelt")
	P.d.res.wood = wood
	# Preise der Stufen 2–5 (× 2,2 je Stufe), Teilzahlung bleibt im Spielstand
	var t1: Dictionary = P.outpost_pad_price(0, D.OUTPOST_PADS[8])
	for pd in D.OUTPOST_PADS:
		if String(pd.key) == "t3":
			var t3: Dictionary = P.outpost_pad_price(0, pd)
			T._check(int(t3.coins) == int(ceil(60 * 2.2)), "Turm 3 kostet × 2,2 (%d)" % int(t3.coins))
		if String(pd.key) == "special_5":
			T._check(int(P.outpost_pad_price(6, pd).coins) == int(ceil(120.0 * 9.0 * pow(2.2, 4))), "Spezialbau Stufe 5 im Krater")
	T._check(int(t1.coins) == 60 and int(t1.wood) == 30 and int(t1.stone) == 20, "Turm 1 im Grüntal: Preis laut Tabelle")
	var staub_price := P.outpost_pad_price(2, D.OUTPOST_PADS[8])
	T._check(staub_price.has("metal") and not staub_price.has("wood"), "Staubebene: Metall statt Holz")
	P.outpost_pay("sumpf", "depot", "coins", 17.0)
	var snap: Dictionary = JSON.parse_string(JSON.stringify(P.d.outposts))
	T._check(int(snap.sumpf.paid.depot.coins) == 17, "Teilzahlung steht im Spielstand")
	# Talbund
	T._check(not P.outpost_talbund(), "noch kein Talbund")
	for a in D.AREAS:
		P.outpost_set_level(String(a.key), 3)
	T._check(P.outpost_talbund(), "alle sieben auf Stufe 3: Talbund")
	# Belagerung: verlorene Flut belagert genau eine (die höchste)
	P.outpost_set_level("frost", 5)
	P.outpost("gruental").level = 3
	P.flood_result(false, 0.0, false, 0)
	T._check(P.outpost_besieged() == "frost", "verlorene Flut belagert die höchste Außenbasis")
	T._check(P.outpost_bonus("wall_hp") < 0.001, "Vorteil ruht während der Belagerung")
	P.flood_result(false, 0.0, false, 0)
	var sieged := 0
	for ak in P.d.outposts:
		if bool(P.d.outposts[ak].siege):
			sieged += 1
	T._check(sieged == 1, "nie mehr als eine Belagerung (%d)" % sieged)
	T._check(P.fuel_cost(5) == int(ceil(float(D.AREAS[5].fuel) * 0.5 * (1.0 - P.cmd_bonus("fuel")) * (1.0 - P.outpost_bonus("fuel")))), "Befreiung kostet halben Treibstoff")
	T._check(P.missions_for(5) == ["befreiung"], "Weltkarte bietet die Befreiung an")
	P.outpost_relieve("frost")
	T._check(P.outpost_bonus("wall_hp") > 0.19 and P.outpost_level("frost") == 5, "nach der Befreiung wirkt der Vorteil wieder, nichts zurückgestuft")


# ---------------------------------------------------------------- Welt (Paket 3)
func _start(area: int, mission := "expedition") -> Node:
	G.autotest = ""
	G.main.start_expedition(area, mission, 0)
	await T._wait(0.4)
	return G.main.world


func _world() -> void:
	_fresh()
	P.d.vehicle_sel = ""
	var e = await _start(0)
	T._check(e.phase == "land", "erster Besuch beginnt mit Ankommen")
	T._check(e.exits_from_start() == 0 and not e.path_to_edge(), "vor Phase 3: kein Weg aus der Landezone")
	# Landezone hält Pflichtpreise + 30 %
	var need := {}
	for pd in D.OUTPOST_PADS:
		if int(pd.level) == 1 and bool(pd.get("must", false)):
			var pr := P.outpost_pad_price(0, pd)
			for r in pr:
				need[r] = int(need.get(r, 0)) + int(pr[r])
	var have := {}
	for n in e.nodes:
		if n.ring == 0:
			have[n.res] = float(have.get(n.res, 0.0)) + n.total
	for r in need:
		T._check(float(have.get(r, 0.0)) >= float(need[r]) * 1.3 - 0.5, "Landezone: genug %s (%d für %d)" % [r, int(have.get(r, 0.0)), int(need[r])])
	# Abbauen: stillstehen neben einer Quelle
	var node = null
	for n in e.nodes:
		if n.ring == 0 and n.res != "coins" and not n.gone:
			node = n
			break
	e.hero.dismount()
	var stand: Vector2 = e._stand(node, node.p + Vector2(3, 0))
	e.hero.global_position = Vector3(stand.x, 0, stand.y)
	e.hero.test_wish = Vector2.ZERO
	var before: float = float(e.loot.get(node.res, 0.0))
	await T._wait(4.5)
	T._check(float(e.loot.get(node.res, 0.0)) > before, "Stillstehen an der Quelle baut ab (%s %.0f)" % [node.res, float(e.loot.get(node.res, 0.0))])
	# Bezahlen auf dem Bauplatz: Teilbetrag
	e.loot["coins"] = 10.0
	var zp = e.outpost.pads.zentrale
	e.hero.global_position = Vector3(zp.center.x, 0, zp.center.y)
	await T._wait(1.0)
	var paid := float(P.outpost_paid("gruental", "zentrale").get("coins", 0.0))
	T._check(paid >= 9.99 and e.field_coins() == 0, "Rucksack fließt in den Bauplatz (%.0f)" % paid)
	e.hero.test_wish = null
	var c0: Vector2 = e.outpost.C
	e.abort()
	await T._wait(0.3)
	e = await _start(0)
	T._check(absf(float(e.outpost.pads.zentrale.due().coins) - (40.0 - paid)) < 0.01, "Teilzahlung bleibt nach Abbruch erhalten")
	T._check(e.outpost.C == c0, "Außenbasis steht immer am selben Ort")
	# Aufbau bis zum Ende (Admin), dann Erkunden
	e.admin_outpost_done()
	await T._wait(0.3)
	T._check(e.phase == "explore" and P.outpost_level("gruental") == 1, "Großangriff überstanden: Stufe 1, Phase Erkunden")
	T._check(e.exits_from_start() >= 3 and e.path_to_edge(), "danach mindestens drei Wege (%d)" % e.exits_from_start())
	T._check(e.outpost.pads.has("t3") and e.outpost.pads.has("special_2"), "Bauplätze der Stufe 2 erscheinen")
	# Held fällt: Rucksack halbiert, Depot nicht
	e.loot["stone"] = 40.0
	e.depot["wood"] = 50.0
	e._recalc_weight()
	e.hero.hurt(1.0e6)
	await T._wait(0.2)
	T._check(absf(float(e.loot.get("stone", 0.0)) - 20.0) < 0.01 and float(e.depot.wood) == 50.0, "Rucksack eines gefallenen Helden halbiert, Depot bleibt")
	await T._wait(7.5)
	T._check(e.hero.alive, "Wiedereinstieg an der Zentrale")
	# Heimkehr: Depot ins Lager
	P.d.res.wood = 0
	P.d.res.stone = 0
	var z = e.outpost.zentrale
	e.hero.global_position = Vector3(z.mid.x + e.outpost.s.x * 4.5, 0, z.mid.y + e.outpost.s.y * 4.5)
	T._check(e.can_go_home(), "Heimkehren an der Zentrale möglich")
	e.go_home()
	T._check(e.ended and e.result.success, "Heimkehr beendet die Expedition")
	T._check(P.res("wood") == 50 and P.res("stone") == 20, "Depot und Rucksack landen im Lager (Holz %d, Stein %d)" % [P.res("wood"), P.res("stone")])
	await T._wait(0.3)
	# zweiter Besuch: startet in der fertigen Außenbasis
	e = await _start(0)
	T._check(e.phase == "explore" and e.outpost.built_ok("zentrale") and e.outpost.built_ok("special") and e.outpost.C == c0, "zweiter Besuch startet in der fertigen Außenbasis")
	T._check(e.hero.pos2().distance_to(e.outpost.C) < 20.0, "Start vor dem Tor der Außenbasis")
	# Stufen 2 bis 5 über Bauplätze
	for lv in range(2, 6):
		e.admin_outpost_done()
		await T._wait(0.1)
		T._check(P.outpost_level("gruental") == lv, "Außenbasis Stufe %d" % lv)
	T._check(e.outpost.built_ok("t4") and e.outpost.built_ok("depot_5"), "Turm 4 und großes Depot stehen")
	var t0 := Time.get_ticks_usec()
	e.field.rebuild()
	print("EXP Neuberechnung des Richtungsfelds (120 × 120): %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	var rb0: int = e.field.rebuilds
	await T._wait(2.5)
	print("EXP Neuberechnungen in 20 s: %d" % (e.field.rebuilds - rb0))
	print("EXP Gegnerlogik %.2f ms bei %d Gegnern" % [e.horde.logic_ms, e.horde.alive])
	# Hinweis: Die Grenze von 4 ms prüft der Bot (--autotest=exp, max_logic_ms); hier nur zur Information,
	# weil der Wert direkt nach dem Admin-Ausbau (alle Gegner jagen den Helden) auf dieser Maschine schwankt.
	# Boss-Schaden: Kopfgeld-Boss hat weniger Leben mit Forschungsstation
	# (der Vorteil wirkt in horde.damage beim Treffer, nicht über weniger Leben)
	var b0 = e.spawn_boss_at(Vector2(60, 60))
	var l0: float = b0.hp
	e.horde.damage(b0, 300.0)
	var d0: float = l0 - b0.hp
	P.outpost_set_level("krater", 1)
	var b1 = e.spawn_boss_at(Vector2(60, 64))
	var l1: float = b1.hp
	e.horde.damage(b1, 300.0)
	var d1: float = l1 - b1.hp
	T._check(absf(d1 / maxf(d0, 0.01) - 1.08) < 0.01, "Boss-Schaden +8 %% (Treffer %.0f → %.0f)" % [d0, d1])
	e.abort()
	await T._wait(0.3)
	# alle Gebiete lassen sich erzeugen
	for i in D.AREAS.size():
		e = await _start(i)
		T._check(e.nodes.size() > 30 and e.pois.size() >= 5 and e.barriers.size() == 3, "Gebiet %d erzeugt (%d Quellen, %d Orte)" % [i, e.nodes.size(), e.pois.size()])
		e.abort()
		await T._wait(0.2)


func _relief() -> void:
	P.outpost_set_level("gruental", maxi(1, P.outpost_level("gruental")))
	for ak in P.d.outposts:
		P.d.outposts[ak].siege = false
	P.outpost("gruental").siege = true
	var e = await _start(0, "befreiung")
	T._check(e.phase == "relief" and e.mission == "befreiung", "Befreiung startet vor der Außenbasis")
	await T._wait(1.0)
	e.admin_skip_phase()
	await T._wait(0.3)
	T._check(e.ended and e.result.success and P.outpost_besieged() == "", "nach der Befreiung ist die Belagerung vorbei")
	await T._wait(0.2)


func _screens() -> void:
	G.main.goto_base()
	await T._wait(0.3)
	G.main.screens.open("expedition")
	await T._wait(0.3)
	T._check(G.main.screens.is_open(), "Weltkarte öffnet")
	for i in D.AREAS.size():
		G.main.screens.st["area"] = i
		G.main.screens.refresh()
		await T._wait(0.05)
	G.main.screens.close()
	G.main.hud._show_outposts()
	await T._wait(0.1)
	T._check(G.main.hud.modal_open(), "Liste der Außenbasen öffnet")
	G.main.hud._close_modal()
