extends RefCounted
## V6 Paket B: Szenen nur für Bildschirmfotos (--b6=<szene>, zusammen mit shot2.sh). Im Spiel ohne Wirkung.
##   ladder  – geschlossener Mauerring, Schleimlinge mit Leitern klettern über die Nordmauer (Türme ruhen)
##   damage  – beschädigte Mauern, glitzernde Hindernisse, ein verletzter Bewohner, Held im Tümpel
##   flier   – Luftabwehr im Norden, Flieger weichen aus
##   breach  – Brecher laufen zur Holzmauer in einem Metallring

const D = preload("res://src/data.gd")
const BState = preload("res://src/basis_state.gd")
const Nature = preload("res://src/base_nature.gd")


static func run(w) -> void:
	await w.get_tree().create_timer(0.3).timeout
	match G.arg("b6"):
		"ladder":
			await _ladder(w)
		"damage":
			await _damage(w)
		"flier":
			await _flier(w)
		"breach":
			await _breach(w)
		"result":
			await _result(w)
		"layouts":
			preload("res://src/basis_ui.gd").layouts_dialog(G.hud, "Speicher %d: %s" % [1, "Passt: %d Gebäude bekommen ihren Platz." % 64], preload("res://src/layout_code.gd").encode())


static func _ring(r: int, level: int) -> void:
	for b in P.d.buildings.duplicate():
		if String(b.key) == "wall" or String(b.key) == "tor":
			P.d.buildings.erase(b)
	var bk := P.bunker()
	var cx := int(bk.x) + 2
	var cy := int(bk.y) + 2
	for i in range(-r, r + 1):
		for p in [[cx + i, cy - r], [cx + i, cy + r], [cx - r, cy + i], [cx + r, cy + i]]:
			if P.cells_free(int(p[0]), int(p[1]), 1, 1):
				var b := P._add_building("wall", int(p[0]), int(p[1]), 0, level)
				b.done_at = 0.0
	P.buildings_changed.emit()


static func _ladder(w) -> void:
	P.d.week.number = maxi(int(P.d.week.number), 6)
	P.d.week.dirs = [0, 0]
	_ring(12, 2)
	await w.get_tree().create_timer(0.3).timeout
	w.start_flood(true)
	for t in w.towers:
		t.active = false
	var bk := P.bunker()
	var z: float = (int(bk.y) + 2 - 12 - 22) * 2.0 + 1.0
	w.hero.global_position = Vector3(0.0, 0, 50.0)
	w.cam.override_target = Vector3((int(bk.x) + 2 - 22) * 2.0, 0, z)
	w.cam.snap()


static func _breach(w) -> void:
	P.d.week.number = maxi(int(P.d.week.number), 6)
	P.d.week.dirs = [0, 0]
	_ring(12, 3)
	var bk := P.bunker()
	for b in P.d.buildings:
		if String(b.key) == "wall" and int(b.y) == int(bk.y) + 2 - 12 and absi(int(b.x) - int(bk.x) - 6) <= 0:
			b.level = 1
	P.buildings_changed.emit()
	await w.get_tree().create_timer(0.3).timeout
	w.start_flood(true)
	w._queue.clear()
	for t in w.towers:
		t.active = false
	for i in 4:
		w.horde.spawn(D.E_BRUTE, Vector2(-14.0 + i * 3.0, -52.0), 1.0, 1.0)
	w.hero.global_position = Vector3(8.0, 0, -12.0)
	w.cam.snap()


static func _flier(w) -> void:
	var bk := P.bunker()
	var aa := P._add_building("luftabwehr", int(bk.x) + 1, int(bk.y) - 8, 0, 1)
	aa.done_at = 0.0
	P.buildings_changed.emit()
	await w.get_tree().create_timer(0.3).timeout
	w.start_flood(true)
	w._queue.clear()
	for i in 14:
		w.horde.spawn(D.E_FLYER, Vector2(-6.0 + i, -60.0 - (i % 3) * 2.0), 6.0, 1.0)
	w.hero.global_position = Vector3(-6.0, 0, -6.0)
	w.cam.snap()


static func _damage(w) -> void:
	var k := 0
	for b in P.d.buildings:
		if String(b.key) == "wall":
			k += 1
			if k % 3 == 0:
				b["dmg"] = 0.5 if k % 2 == 0 else 0.8
	# zwei glitzernde Hindernisse vor dem Bunker
	var bk := P.bunker()
	for i in 2:
		var x := int(bk.x) - 3 + i * 7
		var y := int(bk.y) + 7
		if P.cells_free(x, y, 1, 1):
			var o := P._add_building("hind_busch" if i == 0 else "hind_stein", x, y, 0, 1)
			o["find_roll"] = true
			o["find"] = "gems"
	BState.injure(3)
	P.buildings_changed.emit()
	await w.get_tree().create_timer(0.4).timeout
	w.life._update_injured()
	if G.arg("pond") != "":
		w.hero.global_position = Vector3(Nature.POND.x, 0, Nature.POND.y + 1.2)
		w.cam.snap()
		for i in 120:                                    # kleine Kreise im Tümpel
			var a := i * 0.2
			G.touch_move = Vector2(cos(a), sin(a)) * 0.45
			await w.get_tree().create_timer(0.05).timeout
			if w.hero.pos2().distance_to(Nature.POND) > 1.6:
				var back: Vector2 = Nature.POND + (w.hero.pos2() - Nature.POND).normalized() * 1.0
				w.hero.global_position = Vector3(back.x, 0, back.y)
		G.touch_move = Vector2.ZERO
	else:
		var c: Vector2 = w.bunker_node.mid + Vector2(2, 12)
		w.hero.global_position = Vector3(c.x, 0, c.y)
		w.cam.snap()
		# Verletzte in die Nähe holen
		var n := 0
		for npc in w.npc_board.npcs:
			if npc.injured and n < 2:
				npc.show_at(c + Vector2(-3.0 + n * 6.0, -2.0))
				n += 1


static func _result(w) -> void:
	P.d.week.start_day = P.day_index() - 6
	P.d.week.flood_done = false
	w.start_flood(false)
	w._queue.clear()
	await w.get_tree().create_timer(0.5).timeout
	w.walls[0].hurt(1.0e9, true)
	w._finish(true)
