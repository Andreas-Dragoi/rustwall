extends Node
## Flut-Rückblick (V6 Paket B, Kapitel 4.2): Zusammenfassung jeder Flut mit kleiner Karte der Basis.
## Für die selbst gespielte Flut (auch Übung, Layout-Test) zeichnet dieser Knoten während der Flut echte Daten auf:
## Mauerbrüche (Ort, Welle), verlorene Gebäude, Schaden je Turm (über horde.dmg_src), Welle für Welle.
## Für die verpasste Flut (P._auto_flood) erzeugt simulate() einen Rückblick aus der Berechnung.
## Gespeichert in P.d.replays (neueste zuerst, höchstens DB.REPLAY_KEEP). Anzeige: Bildschirm „rueckblick“.
##
## Eintrag: {"v", "time", "week", "mode" (flood|practice|test|auto), "calc" (berechnet), "win", "stars", "hp", "kills",
##   "weather", "night", "dirs", "grid": [Ursprung, Größe], "map": {"b": [[key, x, y, w, h]], "w": [[x, y, tier]]},
##   "waves": [{"n", "k", "br": [[x, y]], "lost": [[key, x, y, w, h]], "t", "hp"}], "towers": [[key, x, y, w, h, Schaden]], "seen"}

const D = preload("res://src/data.gd")
const DB = preload("res://src/data_basis.gd")

var w                              # base_world
var rec := {}
var _wave := 0
var _t := 0.0
var _kills0 := 0
var _spawn_seen := 0


func setup(world) -> void:
	w = world
	name = "FlutRueckblick"
	rec = snapshot_map()
	rec["mode"] = "test" if bool(w.get("layout_test")) else ("practice" if w.mode == "practice" else "flood")
	rec["weather"] = String(w.flood.get("weather", "klar"))
	rec["night"] = bool(w.flood.get("night", false))
	rec["dirs"] = (w.flood.get("dirs", [0, 1]) as Array).duplicate()
	rec["waves"] = []
	rec["calc"] = false
	for t in w.towers:
		if is_instance_valid(t):
			t.dealt = 0.0


## Karte der Basis aus dem Spielstand (Gebäude als Rechtecke, Mauern als Punkte).
static func snapshot_map() -> Dictionary:
	var bl: Array = []
	var wl: Array = []
	for b in P.d.buildings:
		var def: Dictionary = D.BUILDINGS.get(String(b.key), {})
		if def.is_empty() or String(def.cat) == "obstacle":
			continue
		if String(b.key) == "wall":
			wl.append([int(b.x), int(b.y), clampi(int(b.level) - 1, 0, 2)])
			continue
		var s := P.size_of(String(b.key), int(b.rot))
		bl.append([String(b.key), int(b.x), int(b.y), s.x, s.y])
	return {"v": 1, "time": P.now(), "week": int(P.d.week.number), "grid": [P.grid_origin(), P.grid_size()], "map": {"b": bl, "w": wl},
		"seen": false}


func _physics_process(dt: float) -> void:
	if w == null or not is_instance_valid(w):
		return
	_t += dt
	if w.wave_idx != _wave:
		_close_wave()
		_wave = w.wave_idx
		(rec.waves as Array).append({"n": 0, "k": 0, "br": [], "lost": [], "t": 0.0, "hp": 1.0})
		_kills0 = w.horde.kills
		_t = 0.0
	var cur := _cur()
	if not cur.is_empty():
		cur.t = snappedf(_t, 0.1)
		cur.k = w.horde.kills - _kills0
		cur.n = maxi(int(cur.n), int(cur.k) + w.enemies_left())


func _cur() -> Dictionary:
	var wl: Array = rec.get("waves", [])
	return wl[wl.size() - 1] if wl.size() > 0 else {}


func _close_wave() -> void:
	var cur := _cur()
	if cur.is_empty():
		return
	cur.hp = snappedf(w.bunker_node.hp / maxf(1.0, w.bunker_node.max_hp), 0.01) if w.bunker_node != null else 0.0


## base_world.on_wall_destroyed / on_structure_destroyed
func on_wall(seg) -> void:
	var cur := _cur()
	if not cur.is_empty():
		(cur.br as Array).append([int(seg.x), int(seg.y)])


func on_building(s) -> void:
	var cur := _cur()
	if cur.is_empty() or s.b.is_empty():
		return
	if s.gate:
		(cur.br as Array).append([int(s.b.x), int(s.b.y)])
		return
	(cur.lost as Array).append([String(s.key), int(s.b.x), int(s.b.y), s.size.x, s.size.y])


## Flutende: Ergebnis eintragen, Türme nach Schaden, speichern. Rückgabe: der Eintrag.
func finish(result: Dictionary) -> Dictionary:
	_close_wave()
	rec["win"] = bool(result.get("win", false))
	rec["stars"] = int(result.get("stars", 0))
	rec["hp"] = float(result.get("hp_ratio", 0.0))
	rec["kills"] = int(result.get("kills", w.horde.kills))
	var tl: Array = []
	for id in w.nodes:
		var s = w.nodes[id]
		if s.tower != null and is_instance_valid(s.tower) and not s.b.is_empty():
			tl.append([String(s.key), int(s.b.x), int(s.b.y), s.size.x, s.size.y, int(round(s.tower.dealt))])
	tl.sort_custom(func(a, b): return int(a[5]) > int(b[5]))
	rec["towers"] = tl
	rec["seen"] = true                 # gespielte Flut: der Rückblick steht im Ergebnis; „neu“ sind nur verpasste Fluten
	store(rec)
	return rec


static func store(r: Dictionary) -> void:
	if not P.d.has("replays"):
		P.d["replays"] = []
	var l: Array = P.d.replays
	l.push_front(r)
	while l.size() > DB.REPLAY_KEEP:
		l.pop_back()
	P.mark()


static func latest() -> Dictionary:
	var l: Array = P.d.get("replays", [])
	return l[0] if l.size() > 0 else {}


static func unseen() -> int:
	var n := 0
	for r in P.d.get("replays", []):
		if not bool(r.get("seen", true)):
			n += 1
	return n


## Rückblick für die verpasste Flut aus der Berechnung (P._auto_flood): wo die Mauer brach, welche Türme am meisten
## Schaden machten, verlorene Gebäude, Welle für Welle – nach festen Regeln aus Aufbau und Stärke der Flut.
static func simulate(fd: Dictionary, win: bool, ratio: float, out: Dictionary) -> Dictionary:
	var r := snapshot_map()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(P.d.week.number) * 104729 + int(r.time) % 9973
	r["mode"] = "auto"
	r["calc"] = true
	r["win"] = win
	r["stars"] = int(out.get("stars", 0))
	r["weather"] = "klar"
	r["night"] = false
	r["dirs"] = (P.d.week.get("dirs", [0, 1]) as Array).duplicate()
	var waves := int(fd.waves)
	var total := int(fd.total)
	var wsum := 0.0
	for i in waves:
		wsum += 1.0 + i * 0.5
	var o := P.grid_origin()
	var n := P.grid_size()
	var cx := o + n * 0.5
	# Mauern nach Lage: außen und Richtung der Flut zuerst, schwache vor starken
	var walls: Array = []
	for b in P.d.buildings:
		if String(b.key) == "wall" or String(b.key) == "tor":
			var v := Vector2(int(b.x) - cx, int(b.y) - cx)
			var face := -1.0
			for d in r.dirs:
				face = maxf(face, v.normalized().dot([Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)][int(d)]))
			var score := face * 10.0 + v.length() * 0.3 - float(b.level) * 4.0 - (6.0 if String(b.key) == "tor" else 0.0) + rng.randf() * 2.0
			walls.append([score, int(b.x), int(b.y)])
	walls.sort_custom(func(a, c): return a[0] > c[0])
	var others: Array = []
	for b in P.d.buildings:
		var def: Dictionary = D.BUILDINGS.get(String(b.key), {})
		if def.is_empty() or String(def.cat) in ["obstacle", "wall", "deco", "trap"] or String(b.key) == "bunker":
			continue
		var s := P.size_of(String(b.key), int(b.rot))
		var v2 := Vector2(int(b.x) - cx, int(b.y) - cx)
		others.append([v2.length() + rng.randf() * 3.0, String(b.key), int(b.x), int(b.y), s.x, s.y])
	others.sort_custom(func(a, c): return a[0] > c[0])
	# Mauerbrüche: je schwächer die Verteidigung, desto mehr; verlorene Flut: auch Gebäude
	var breaks := int(round(clampf(1.6 - ratio, 0.0, 1.6) * 6.0)) if win else int(round(4.0 + (1.0 - clampf(ratio, 0.0, 1.0)) * 10.0))
	breaks = mini(breaks, walls.size())
	var lost_n := 0 if win else mini(others.size(), 1 + int((1.0 - clampf(ratio, 0.0, 1.0)) * 5.0))
	var wl: Array = []
	var bi := 0
	var li := 0
	var hp := 1.0
	for i in waves:
		var nn := int(round(float(total) * (1.0 + i * 0.5) / maxf(wsum, 1.0)))
		var share := float(i + 1) / waves
		var wave := {"n": nn, "k": nn, "br": [], "lost": [], "t": snappedf(30.0 + nn * 0.35, 0.1), "hp": 1.0}
		var want_b := int(round(breaks * share * share))
		while bi < want_b:
			(wave.br as Array).append([int(walls[bi][1]), int(walls[bi][2])])
			bi += 1
		if not win:
			var want_l := int(round(lost_n * clampf((share - 0.5) * 2.0, 0.0, 1.0)))
			while li < want_l:
				var ob: Array = others[li]
				(wave.lost as Array).append([ob[1], ob[2], ob[3], ob[4], ob[5]])
				li += 1
			hp = clampf(1.0 - share * (1.2 - ratio * 0.5), 0.0, 1.0)
			if i == waves - 1:
				hp = 0.0
				wave.k = int(nn * clampf(ratio, 0.2, 0.9))
		else:
			hp = clampf(1.0 - share * clampf(1.4 - ratio, 0.0, 0.9) * 0.6, 0.1, 1.0)
		wave.hp = snappedf(hp, 0.01)
		wl.append(wave)
	r["waves"] = wl
	var kills := 0
	for wv in wl:
		kills += int(wv.k)
	r["kills"] = kills
	r["hp"] = float(out.get("hp_ratio", hp)) if win else 0.0
	# Schaden je Turm: Feuerkraft × Lage zur Flutrichtung
	var tl: Array = []
	var tsum := 0.0
	for b in P.d.buildings:
		var def2: Dictionary = D.BUILDINGS.get(String(b.key), {})
		if not def2.has("tower") or P.is_building(b):
			continue
		var t: Dictionary = D.TOWERS[def2.tower]
		var dps: float = float(t.damage) * float(t.rpm) / 60.0 * pow(D.TOWER_DMG_GROWTH, int(b.level) - 1) * (1.0 + float(t.get("splash", 0.0)) * 0.3)
		var s2 := P.size_of(String(b.key), int(b.rot))
		var v3 := Vector2(int(b.x) - cx, int(b.y) - cx)
		var face2 := 0.0
		for d in r.dirs:
			face2 = maxf(face2, v3.normalized().dot([Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)][int(d)]))
		var wgt := dps * (0.6 + face2 * 0.6) * rng.randf_range(0.85, 1.15)
		tsum += wgt
		tl.append([String(b.key), int(b.x), int(b.y), s2.x, s2.y, wgt])
	var dmg_total := float(kills) * 14.0 * float(fd.get("hp", 1.0))
	for e in tl:
		e[5] = int(round(float(e[5]) / maxf(tsum, 0.001) * dmg_total))
	tl.sort_custom(func(a, c): return int(a[5]) > int(c[5]))
	r["towers"] = tl
	return r
