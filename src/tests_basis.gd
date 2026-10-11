extends RefCounted
## Prüfungen für Paket 5 (Lebendige Basis): Wege zwischen allen Türen und Toren, Anpassen nach dem Verschieben,
## Pflanzen nie auf Gebäuden, Tiere (Arten, nie in Gebäuden, verschwinden bei Alarm), Tageszeit, Regen-Schalter,
## Wegkosten für Bewohner, Rechenzeit von Tieren und Wetter.
## Aufruf aus tests.gd (--selftest).

const D = preload("res://src/data.gd")
const Weather = preload("res://src/weather.gd")
const Nature = preload("res://src/base_nature.gd")

var T: Node                      # tests.gd (für _check und _wait)


func _init(tests: Node) -> void:
	T = tests


func run() -> void:
	P.new_game()
	P.no_save = true
	P.debug_setup(6)
	P.no_save = true
	P.speed_up_builds(1.0e9)
	Weather.force = "tag"
	G.main.goto_base()
	await T._wait(1.0)
	var w = G.main.world
	T._check(w.nature != null and w.weather != null and w.get("wildlife") != null, "Basis hat Natur, Wetter und Tiere")
	if w.nature == null or w.get("wildlife") == null:
		return
	var nat = w.nature
	T._check(nat.rebuilds >= 1 and nat.routes.size() > 0, "Wege berechnet (%d Wege)" % nat.routes.size())
	_doors_connected(w, "nach dem Laden")
	T._check(nat.plants_on_buildings() == 0, "keine Pflanze auf einem Gebäude")
	T._check(nat.tree_count() > 0, "Bäume im Baufeld (%d)" % nat.tree_count())
	# Wegkosten für Bewohner
	var on := Vector2.ZERO
	var off := Vector2(1000, 1000)
	for r in nat.routes:
		if r.size() > 3 and nat.on_path(r[r.size() / 2]):
			on = r[r.size() / 2]
			break
	T._check(w.path_cost(on) < w.path_cost(Vector2(-40, -40)), "Weg ist billiger als Wiese (%.2f < %.2f)" % [w.path_cost(on), w.path_cost(Vector2(-40, -40))])
	# Gebäude verschieben: Wege passen sich innerhalb von 2 Sekunden an
	var moved := _move_one(w)
	if moved >= 0:
		var r0: int = nat.rebuilds
		var t0: float = w.time
		var ok := false
		for i in 60:
			await T._wait(0.1)
			if nat.rebuilds > r0 and nat.mask_mix >= 1.0:
				ok = true
				break
		var real_s: float = w.time - t0
		T._check(ok, "Wege nach dem Verschieben neu (%.2f s Spielzeit)" % real_s)
		T._check(real_s <= 2.2, "innerhalb von 2 Sekunden (%.2f s)" % real_s)
		_doors_connected(w, "nach dem Verschieben")
		T._check(nat.plants_on_buildings() == 0, "nach dem Verschieben: keine Pflanze auf einem Gebäude")
	# Tiere
	await T._wait(2.0)
	var wl = w.wildlife
	var kinds: Array = wl.kinds_visible(Vector3.ZERO, 500.0)
	T._check(kinds.size() >= 5, "mindestens 5 Tierarten (%s)" % ", ".join(kinds))
	T._check(wl.animals.size() <= 40, "höchstens 40 Tier-Nodes (%d)" % wl.animals.size())
	var bad := 0
	for i in 20:
		await T._wait(0.3)
		bad += wl.animals_in_buildings()
	T._check(bad == 0, "kein Bodentier in Gebäuden oder Mauern (%d)" % bad)
	# Rechenzeit (Mittel über einige Bilder)
	var us := 0.0
	for i in 30:
		await T.get_tree().process_frame
		us += float(wl.last_us) + float(w.weather.last_us)
	us /= 30.0
	print("BASIS tiere+wetter %.3f ms/Bild, Weg-Neuberechnung %.1f ms" % [us / 1000.0, nat.last_rebuild_ms])
	T._check(us < 1200.0, "Tiere + Wetter unter 1,2 ms je Bild (%.3f ms)" % (us / 1000.0))
	# Tageszeit
	Weather.force = "nacht"
	await T._wait(3.0)
	T._check(w.is_night() and w.daytime == "nacht", "Nacht über Testschalter (%s)" % w.daytime)
	T._check(w.weather.night_k > 0.9, "Nachtstimmung voll eingeblendet (%.2f)" % w.weather.night_k)
	T._check(w.sun.light_energy + w.world_env.ambient_light_energy >= 1.5, "nachts hell genug (Sonne %.2f, Umgebung %.2f)" % [w.sun.light_energy, w.world_env.ambient_light_energy])
	Weather.force = "tag"
	# Regen und Schalter
	Weather.force_rain = 1
	await T._wait(0.5)
	T._check(w.weather.raining, "Regen beginnt (Admin)")
	P.d.settings.rain = false
	await T._wait(0.5)
	T._check(not w.weather.raining, "Regen aus in den Optionen")
	P.d.settings.rain = true
	# Alarm: Tiere verschwinden
	w.start_flood(true)
	await T._wait(1.0)
	var vis := 0
	for a in wl.animals:
		if a.n.visible:
			vis += 1
	T._check(vis < wl.animals.size(), "Alarm: Tiere fliehen")
	await T._wait(14.0)
	vis = 0
	for a in wl.animals:
		if a.n.visible:
			vis += 1
	T._check(vis == 0, "Alarm: alle Tiere verschwunden (%d noch da)" % vis)
	w.back_to_peace()
	await T._wait(1.0)
	Weather.force = ""


## Jedes Gebäude mit Tür und jedes Tor liegt am Wegenetz.
func _doors_connected(w, when: String) -> void:
	var nat = w.nature
	var missing: Array = []
	for id in w.nodes:
		var s = w.nodes[id]
		var cat := String(s.def.cat)
		if not (cat in ["core", "prod", "special"] or s.key == "tor"):
			continue
		var p: Vector2 = s.mid
		if s.key != "tor":
			var dp: Array = nat.door_point(s)
			p = dp[0] + dp[1] * 1.0
		var c: Vector2i = w.world_to_cell(p)
		var hit := false
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var x := c.x + dx
				var y := c.y + dy
				if x >= 0 and y >= 0 and x < D.GRID_MAX and y < D.GRID_MAX and nat.path_cells[x + y * D.GRID_MAX] == 1:
					hit = true
		if not hit:
			missing.append(s.key)
	T._check(missing.is_empty(), "Wege zu allen Türen und Toren %s (fehlt: %s)" % [when, ", ".join(missing)])


## Verschiebt ein Produktionsgebäude auf einen freien Platz; Rückgabe: ID oder -1.
func _move_one(w) -> int:
	for b in P.d.buildings:
		if String(D.BUILDINGS[b.key].cat) != "prod":
			continue
		var sz := P.size_of(String(b.key), int(b.rot))
		var o := P.grid_origin()
		var n := P.grid_size()
		for y in range(o + 2, o + n - sz.y - 2):
			for x in range(o + 2, o + n - sz.x - 2):
				if absi(x - int(b.x)) < 4 and absi(y - int(b.y)) < 4:
					continue
				if P.cells_free(x, y, sz.x, sz.y, int(b.id)) and P.move(int(b.id), x, y, int(b.rot)):
					return int(b.id)
	return -1
