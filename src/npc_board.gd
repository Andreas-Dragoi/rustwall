extends Node
## Aufgabenbrett und Verwaltung der Bewohner der Hauptbasis (Paket 2 – Kluge Bewohner).
## Erzeugt Aufgaben aus dem Zustand der Basis (Baustelle, Schaden, Produktion, Lieferung, Nacht, Alarm, Sieg),
## verteilt Berufe nach den vorhandenen Gebäuden (Tabelle 2.1) und bewegt alle Bewohner (npc.gd) mit Zeitscheiben
## für die Wegsuche (nav_grid.gd). Eine Aufgabe ist {kind, steps, prio, ...}; die Schritte beschreibt npc.gd.

const D = preload("res://src/data.gd")
const Models = preload("res://src/models.gd")
const Humanoid = preload("res://src/humanoid.gd")
const Npc = preload("res://src/npc.gd")
const NavGrid = preload("res://src/nav_grid.gd")

## Produktionsberufe: Gebäude -> Beruf
const PROD_JOB := {"saege": "holz", "steinbruch": "stein", "presse": "schrott", "raffinerie": "technik", "generator": "technik"}
## Lieblingsorte der freien Helden: [Gebäude, Ersatz, Animation, Ding, Text]
const HERO_SPOT := {
	"greta": ["quartier", "bunker", "hammer", "c_crate", "Backt Brot am Quartier"],
	"bruno": ["training", "quartier", "pick_up", "c_stone", "Stemmt Gewichte"],
	"ada": ["werkstatt", "bunker", "hammer", "c_hammer", "Schraubt an der Werkstatt"],
	"yuki": ["wachturm", "bunker", "wave", "", "Übt am Wachturm"],
	"mika": ["bunker", "bunker", "pay", "c_can", "Prüft den Schlauch"],
	"jona": ["funkturm", "bunker", "pay", "c_crate", "Sortiert Post am Funkturm"],
}

var w                            # base_world
var nav                          # NavGrid
var npcs: Array = []
var logic_ms := 0.0              # Logik aller Bewohner in diesem Bild (ohne Animation)
var logic_max := 0.0
var sites := {}                  # Baustelle (Gebäude-ID) -> {seen: Zeit, served: Zeit oder -1}
var work_seen := {}              # Gebäude-ID -> Zeit, zu der zuletzt jemand dort gearbeitet hat (für Tests)
var repair_mode := false
var _benches: Array = []         # {n: Node3D, p: Vector2, face: Vector2, used: [npc, npc]}
var _t := 0.0
var _alarm := false
var _night := false
var _rng := RandomNumberGenerator.new()
var _rr := {}                    # Zähler für Rundlauf je Beruf
var _pickups := 0
var _gates: Array = []           # Mittelpunkte der Tore
var _nav_v := -1


func _init(world) -> void:
	w = world
	_rng.randomize()
	nav = NavGrid.new(w.field, w, _area())
	P.buildings_changed.connect(_on_changed)
	P.pickups_changed.connect(_on_pickups)
	P.level_up.connect(_on_level)
	_pickups = P.d.pickups.size()


func _ready() -> void:
	name = "Bewohner"
	_roster()


func _area() -> float:
	return P.grid_size() * 0.5 * D.CELL + 8.0


func _on_changed() -> void:
	nav.set_area(_area())
	nav.dirty = true
	_t = 0.0                         # Baustellen sofort prüfen


func _on_level(_lv: int) -> void:
	if w.hero != null:
		cheer_near(w.hero.pos2(), 10.0, 1.5)


func _on_pickups() -> void:
	var n: int = P.d.pickups.size()
	if n > _pickups and P.d.pickups.size() > 0:
		var pk: Dictionary = P.d.pickups[P.d.pickups.size() - 1]
		var s = _node_of(String(pk.get("at", "bunker")))
		if s != null:
			cheer_near(s.mid, 10.0, 1.5)
	_pickups = n


# ---------------------------------------------------------------- Bewohner und Berufe
func _settler_count() -> int:
	return mini(3 + P.bunker_level(), 13)


func _free_heroes() -> Array:
	var out: Array = []
	for hk in D.HERO_ORDER:
		if P.hero_unlocked(hk) and hk != String(P.d.hero_sel) and not P.hero_busy(hk):
			out.append(hk)
	return out


## Passt die Zahl der Bewohner und freien Helden an und verteilt die Berufe.
func _roster() -> void:
	var want := _settler_count()
	var plain: Array = npcs.filter(func(n): return n.hero_key == "")
	while plain.size() < want:
		var n := _spawn("")
		plain.append(n)
	while plain.size() > want:
		var n2 = plain.pop_back()
		_remove(n2)
	var heroes := _free_heroes()
	for n in npcs.duplicate():
		if n.hero_key != "" and not heroes.has(n.hero_key):
			_remove(n)
	for hk in heroes:
		var has := false
		for n in npcs:
			if n.hero_key == hk:
				has = true
		if not has:
			_spawn(hk)
	_assign_jobs()


func _spawn(hk: String) -> Object:
	var h := Humanoid.new()
	w.add_child(h)
	h.build({"kind": hk if hk != "" else "settler"})
	h.scale = Vector3.ONE * D.CHAR_SCALE * (1.0 if hk != "" else 0.92)
	var home: Vector2 = _door("bunker")
	var p: Vector2 = nav.free_near(home + Vector2(_rng.randf_range(-4, 4), _rng.randf_range(0, 4)))
	h.position = Vector3(p.x, 0, p.y)
	var i := 0
	var used := {}
	for n in npcs:
		used[n.idx] = true
	while used.has(i):
		i += 1
	var n = Npc.new(self, h, i)
	n.hero_key = hk
	n.name = String(D.HEROES[hk].name) if hk != "" else String(D.NPC_NAMES[i % D.NPC_NAMES.size()])
	n.job = "held" if hk != "" else ""
	n.greet_cd = _rng.randf_range(0.0, 6.0)
	npcs.append(n)
	npcs.sort_custom(func(a, b): return a.idx < b.idx)
	return n


func _remove(n) -> void:
	npcs.erase(n)
	if is_instance_valid(n.h):
		n.h.queue_free()


## Berufe nach vorhandenen Gebäuden (Tabelle 2.1). Nach einer Flut werden mindestens zwei Bewohner Handwerker.
func _assign_jobs() -> void:
	var plain: Array = npcs.filter(func(n): return n.hero_key == "")
	var order: Array = ["bau"]
	var prod: Array = []
	for key in ["saege", "steinbruch", "presse", "raffinerie", "generator"]:
		for s in _nodes_of(key):
			prod.append(PROD_JOB[key])
	var first := {}
	for j in prod:
		if not first.has(j):
			first[j] = true
			order.append(j)
	if _nodes_of("lager").size() > 0:
		order.append("traeger")
	var guard: bool = w.walls.size() > 0 or _nodes_of("tor").size() > 0 or _nodes_of("wachturm").size() > 0
	if guard:
		order.append("wache")
	if _nodes_of("blumen").size() > 0:
		order.append("gaertner")
	# je weiteres Produktionsgebäude ein weiterer Arbeiter, dann Wachen, Träger, Baumeister im Wechsel
	var count := {}
	for j in prod:
		count[j] = int(count.get(j, 0)) + 1
	for j in count:
		for k in int(count[j]) - 1:
			order.append(j)
	var extra: Array = ["wache", "traeger", "bau", "gaertner"]
	var k2 := 0
	while order.size() < plain.size():
		var e: String = extra[k2 % extra.size()]
		k2 += 1
		if (e == "wache" and not guard) or (e == "traeger" and _nodes_of("lager").is_empty()) or (e == "gaertner" and _nodes_of("blumen").is_empty()):
			if k2 > 12:
				order.append("bau")
			continue
		order.append(e)
	if repair_mode:
		# Handwerker zuerst aus den hinteren Plätzen, mindestens zwei
		var nh := maxi(2, int(plain.size() / 3))
		for i in nh:
			var at := order.size() - 1 - i
			if at >= 1 and at < plain.size():
				order[at] = "hand"
			elif plain.size() > i:
				order[mini(plain.size() - 1, order.size() - 1 - i)] = "hand"
	for i in plain.size():
		var n = plain[i]
		var j: String = order[i] if i < order.size() else "traeger"
		if n.job != j:
			n.job = j
			if n.task.get("kind", "") != "alarm" and n.task.get("kind", "") != "build":
				n.task = {}
				n.state = "idle" if not n.hidden else n.state


# ---------------------------------------------------------------- Bild für Bild
func update(dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	nav.ensure()
	if _nav_v != nav.version:
		_nav_v = nav.version
		_after_rebuild()
	_t -= dt
	if _t <= 0.0:
		_t = 1.0
		_refresh()
	var hp = w.hero.pos2() if w.hero != null and w.hero.alive and w.hero.visible else null
	var anim_us := 0
	for n in npcs:
		n.tick(dt, nav, npcs, hp)
		if not n.hidden:
			var a0 := Time.get_ticks_usec()
			n.h.tick(dt)
			anim_us += Time.get_ticks_usec() - a0
	logic_ms = float(Time.get_ticks_usec() - t0 - anim_us) / 1000.0
	logic_max = maxf(logic_max, logic_ms)


## Nach einem Neuaufbau des Wegegitters: niemand steht in einem gesperrten Feld, Bänke bleiben frei.
func _after_rebuild() -> void:
	_gates.clear()
	for s in _nodes_of("tor"):
		_gates.append(s.mid)
	for n in npcs:
		if not n.hidden and nav.blocked(n.pos):
			var q: Vector2 = nav.free_near(n.pos)
			n.pos = q
			n.h.position = Vector3(q.x, 0, q.y)
			if n.state == "walk":
				n.state = "plan"
	_place_benches()


## Einmal je Sekunde: Bewohnerzahl, Alarm, Sieg, Nacht, Baustellen, Schäden.
func _refresh() -> void:
	if w.mode == "peace":
		var want := _settler_count()
		var plain := 0
		var hk: Array = []
		for n in npcs:
			if n.hero_key == "":
				plain += 1
			else:
				hk.append(n.hero_key)
		var fh := _free_heroes()
		fh.sort()
		hk.sort()
		if plain != want or fh != hk:
			_roster()
	var alarm: bool = w.mode != "peace" and not (w.ended and bool(w.result.get("win", false)))
	if alarm and not _alarm:
		_start_alarm()
	elif _alarm and not alarm:
		_end_alarm(w.ended and bool(w.result.get("win", false)) or w.mode == "peace")
	_alarm = alarm
	if _alarm:
		_guard_look()
		return
	var night: bool = w.has_method("is_night") and w.is_night()
	if night != _night:
		_night = night
		for n in npcs:
			n.night_home = night and n.idx % 3 != 0
			if night and n.night_home:
				n.give(_night_task(n))
			elif not night and n.task.get("kind", "") == "night":
				n.show_at(nav.free_near(_door("quartier") if _node_of("quartier") != null else _door("bunker")))
				n.give(_next(n))
	if _night:
		return
	_check_sites()
	_check_damage()


func _guard_look() -> void:
	for n in npcs:
		if n.job == "wache" and not n.hidden and w.horde != null:
			var e = w.horde.nearest(n.pos, 30.0)
			n.h.look_target = Vector3(e.p.x, 1.0, e.p.y) if e != null else null


func _start_alarm() -> void:
	for n in npcs:
		n.used_gate = false
		if n.job == "wache":
			n.give(_guard_post(n, true))
		else:
			n.give(_alarm_task(n))


## Nach der Flut: alle kommen heraus (bei Sieg jubeln sie 3 s), nach Schäden werden zwei Handwerker.
func _end_alarm(win: bool) -> void:
	var door := _door("bunker")
	for n in npcs:
		n.h.look_target = null
		if n.hidden:
			var p: Vector2 = nav.free_near(door + Vector2(_rng.randf_range(-3, 3), _rng.randf_range(0.5, 3)))
			n.show_at(p)
		n.task = {}
		n.state = "idle"
		if win:
			n.cheer(3.0)
	_check_damage()


func _check_damage() -> void:
	var dmg := not _damaged().is_empty()
	if dmg != repair_mode:
		repair_mode = dmg
		_assign_jobs()


func _damaged() -> Array:
	var out: Array = []
	for id in w.nodes:
		var s = w.nodes[id]
		if s.alive and s != w.bunker_node and float(s.def.hp) > 0.0 and s.hp < s.max_hp - 0.5 and not s.constructing:
			out.append(s)
	return out


## Baustellen: an jeder Baustelle soll innerhalb von 10 s ein Baumeister stehen.
func _check_sites() -> void:
	var now: float = w.time
	var cur := {}
	for j in P.jobs():
		cur[int(j.id)] = true
	for id in sites.keys():
		if not cur.has(id):
			sites.erase(id)
	for id in cur:
		if not sites.has(id):
			sites[id] = {"seen": now, "served": -1.0}
		var who = null
		for n in npcs:
			if n.task.get("kind", "") == "build" and int(n.task.site) == id:
				who = n
		if who != null:
			continue
		# freien Baumeister suchen, sonst den nächsten Bewohner (keine Wache, kein Held, nicht auf einer anderen Baustelle)
		var site := _site_pos(id)
		var best = null
		var bd := 1.0e9
		for n in npcs:
			if n.hidden or n.hero_key != "" or n.job == "wache" or n.task.get("kind", "") == "build":
				continue
			var dd: float = n.pos.distance_to(site) - (1000.0 if n.job == "bau" else 0.0)
			if dd < bd:
				bd = dd
				best = n
		if best != null:
			best.give(_build_task(best, id))


func _site_pos(id: int) -> Vector2:
	var s = w.nodes.get(id)
	if s != null:
		return s.mid
	var b := P.get_building(id)
	if not b.is_empty():
		var sz := P.size_of(String(b.key), int(b.rot))
		return w.rect_center(int(b.x), int(b.y), sz)
	return Vector2.ZERO


# ---------------------------------------------------------------- Rückmeldungen der Bewohner
## Bewohner ohne Aufgabe fragt nach der nächsten.
func request(n) -> void:
	n.give(_next(n))


func arrived(n, st: Dictionary) -> void:
	var t: Dictionary = n.task
	match String(t.get("kind", "")):
		"build":
			if sites.has(int(t.site)) and float(sites[int(t.site)].served) < 0.0:
				sites[int(t.site)].served = w.time
		"work":
			if t.has("sid"):
				work_seen[int(t.sid)] = w.time


## Während der Animation: Wirkung (Reparatur 2 % je Sekunde je Handwerker, Funken).
func on_act(n, st: Dictionary, dt: float) -> void:
	var t: Dictionary = n.task
	if t.get("kind", "") == "work" and t.has("sid"):
		work_seen[int(t.sid)] = w.time
	if t.get("kind", "") != "repair":
		return
	var s = w.nodes.get(int(t.sid))
	if s == null or not s.alive:
		return
	n.acc += dt
	if n.acc >= 1.0:
		n.acc -= 1.0
		s.repair(D.NPC_REPAIR_RATE)
		if w.fx != null:
			var sp: Vector2 = st.face
			w.fx.puff(Vector3(sp.x, 1.0, sp.y), Color(1.0, 0.75, 0.3), 5, 1.4)


## Wiederholt sich der Schritt? (Baustelle noch offen, Gebäude noch beschädigt, Wache noch im Alarm)
func keep(n, _st: Dictionary) -> bool:
	var t: Dictionary = n.task
	match String(t.get("kind", "")):
		"build":
			return sites.has(int(t.site)) and w.mode == "peace"
		"repair":
			var s = w.nodes.get(int(t.sid))
			return s != null and s.alive and s.hp < s.max_hp - 0.5 and w.mode == "peace"
		"guard":
			return _alarm
	return false


func greet(n) -> void:
	Sfx.play_at("npc_greet", n.h.global_position, -14.0, 1.0, 0.15)


func look_for(_n):
	return null


func gate_near(p: Vector2) -> bool:
	for g in _gates:
		if p.distance_squared_to(g) < 5.5:
			return true
	return false


func cheer_near(p: Vector2, r: float, t: float) -> void:
	for n in npcs:
		if not n.hidden and n.pos.distance_to(p) < r:
			n.cheer(t)
	Sfx.play_at("npc_cheer", Vector3(p.x, 0, p.y), -10.0, 1.0, 0.1)


## Antippen: der nächste Bewohner unter dem Finger zeigt Name, Beruf und Tätigkeit.
func tap(sp: Vector2) -> bool:
	var cam: Camera3D = w.get_viewport().get_camera_3d()
	if cam == null:
		return false
	var best = null
	var bd := 46.0
	for n in npcs:
		if n.hidden:
			continue
		var p3: Vector3 = n.h.global_position + Vector3(0, 1.1, 0)
		if cam.is_position_behind(p3):
			continue
		var d := cam.unproject_position(p3).distance_to(sp)
		if d < bd:
			bd = d
			best = n
	if best == null:
		return false
	var txt := "%s · %s\n%s" % [best.name, best.job_name(), best.doing()]
	if best.hero_key != "":
		txt += "\n„%s“" % _first_sentence(String(D.HEROES[best.hero_key].get("story", "")))
	best.show_sign(txt)
	best.bubble("ui_info")
	Sfx.play("click", -10.0)
	return true


static func _first_sentence(s: String) -> String:
	var i := s.find(". ")
	return s.substr(0, i + 1) if i > 0 else s


# ---------------------------------------------------------------- Aufgaben
func _nodes_of(key: String) -> Array:
	var out: Array = []
	for id in w.nodes:
		var s = w.nodes[id]
		if s.key == key and s.alive:
			out.append(s)
	return out


func _node_of(key: String):
	var l := _nodes_of(key)
	return l[0] if not l.is_empty() else null


## Weltpunkt eines Leerobjekts im Gebäudemodell (door, work_1, work_2, drop).
func _spot(s, nm: String) -> Vector2:
	return s.spot(nm) if s.has_method("spot") else s.mid


## Freier Standpunkt vor einem Arbeitspunkt (Arbeitspunkte liegen oft im gesperrten Gebäudefeld).
func _stand(p: Vector2, toward := Vector2.INF) -> Vector2:
	var q: Vector2 = nav.free_near(p, 10)
	if toward != Vector2.INF and q == p:
		return p
	return q


func _door(key: String) -> Vector2:
	var s = _node_of(key)
	if s == null:
		return w.respawn_point()
	return _stand(_spot(s, "door"))


## Dringlichste Aufgabe des Berufs, sonst Pause.
func _next(n) -> Dictionary:
	if _alarm:
		return _guard_post(n, true) if n.job == "wache" else _alarm_task(n)
	if _night and n.night_home:
		return _night_task(n)
	var t := {}
	match n.job:
		"holz", "stein", "schrott", "technik":
			t = _work_task(n)
		"traeger":
			t = _carry_task(n)
		"wache":
			t = _guard_post(n, false)
		"gaertner":
			t = _garden_task(n)
		"hand":
			t = _repair_task(n)
		"held":
			t = _hero_task(n)
		"bau":
			t = {}
	if t.is_empty() or (n.task.get("kind", "") != "pause" and _rng.randf() < 0.12):
		if t.is_empty() or _rng.randf() < 0.5:
			return _pause_task(n)
	return t


## Gebäude, die dieser Arbeiter betreut (bei mehreren Arbeitern eines Berufs im Rundlauf verteilt).
func _my_buildings(n) -> Array:
	var keys: Array = []
	for k in PROD_JOB:
		if PROD_JOB[k] == n.job:
			keys.append(k)
	var bl: Array = []
	for k in keys:
		bl.append_array(_nodes_of(k))
	bl = bl.filter(func(s): return not s.constructing)
	if bl.is_empty():
		return []
	var mates: Array = npcs.filter(func(o): return o.job == n.job)
	var k2: int = mates.find(n)
	var mine: Array = []
	for i in bl.size():
		if i % mates.size() == k2:
			mine.append(bl[i])
	if mine.is_empty():
		mine.append(bl[k2 % bl.size()])
	return mine


func _work_task(n) -> Dictionary:
	var mine := _my_buildings(n)
	if mine.is_empty():
		return {}
	var c := int(_rr.get(n, 0))
	_rr[n] = c + 1
	var s = mine[c % mine.size()]
	var w1 := _spot(s, "work_1")
	var w2 := _spot(s, "work_2")
	var dr := _spot(s, "drop")
	var steps: Array = []
	match n.job:
		"holz":
			steps = [
				{"at": _stand(w2), "face": w2, "clip": "chop", "dur": 5.0, "prop": "c_hammer", "take": "c_log", "text": "Hackt Holz"},
				{"at": _stand(dr), "face": dr, "clip": "pick_up", "dur": 1.2, "drop": true, "text": "Trägt einen Stamm zum Stapel"}]
		"stein":
			steps = [
				{"at": _stand(w1), "face": w1, "clip": "mine", "dur": 5.0, "prop": "c_hammer", "take": "c_stone", "text": "Klopft am Fels"},
				{"at": _stand(dr), "face": dr, "clip": "pick_up", "dur": 1.2, "drop": true, "text": "Bringt Steine zur Ablage"}]
		"schrott":
			steps = [
				{"at": _stand(w2), "face": w2, "clip": "pick_up", "dur": 1.2, "take": "c_scrap", "text": "Sammelt Schrott"},
				{"at": _stand(w1), "face": w1, "clip": "pick_up", "dur": 1.2, "drop": true, "text": "Trägt Schrott zur Presse"},
				{"at": _stand(w1), "face": w1, "clip": "hammer", "dur": 3.0, "text": "Bedient den Hebel"}]
		"technik":
			steps = [
				{"at": _stand(w1), "face": w1, "clip": "pay", "dur": 3.0, "text": "Prüft die Anzeigen"},
				{"at": _stand(w2), "face": w2, "clip": "hammer", "dur": 3.0, "prop": "c_hammer", "text": "Dreht am Ventil"},
				{"at": _stand(w2), "face": w2 + (w2 - s.mid), "clip": "wave", "dur": 1.5, "text": "Wischt sich die Stirn"}]
	return {"kind": "work", "sid": int(s.b.get("id", -1)) if not s.b.is_empty() else -1, "steps": steps}


func _carry_task(n) -> Dictionary:
	var lager = null
	var ll := _nodes_of("lager")
	if ll.is_empty():
		return {}
	lager = ll[n.idx % ll.size()]
	var src = null
	var text := "Holt eine Kiste"
	if P.d.pickups.size() > 0:
		src = _node_of(String(P.d.pickups[0].get("at", "")))
		text = "Holt die Lieferung"
	if src == null:
		var prod: Array = []
		for k in PROD_JOB:
			prod.append_array(_nodes_of(k))
		prod = prod.filter(func(s): return not s.constructing)
		if prod.is_empty():
			return {}
		src = prod[_rng.randi() % prod.size()]
	var a := _spot(src, "drop")
	var b := _spot(lager, "drop")
	return {"kind": "carry", "steps": [
		{"at": _stand(a), "face": a, "clip": "pick_up", "dur": 1.2, "take": "c_crate", "text": text},
		{"at": _stand(b), "face": b, "clip": "pick_up", "dur": 1.2, "drop": true, "text": "Trägt Kisten zum Lager"}]}


## Wache: Tor, Wachturm oder ein Stück Mauer von innen. Bei Alarm rennt sie dorthin und bleibt.
func _guard_post(n, alarm: bool) -> Dictionary:
	var home: Vector2 = w.bunker_node.mid if w.bunker_node != null else Vector2.ZERO
	var opts: Array = []
	for s in _nodes_of("tor"):
		opts.append([s.mid, "Steht am Tor"])
	for s in _nodes_of("wachturm"):
		opts.append([_spot(s, "work_1"), "Hält Ausschau am Wachturm"])
	if (not alarm or opts.is_empty()) and w.walls.size() > 0:
		var ws = w.walls[(n.idx * 7 if alarm else _rng.randi()) % w.walls.size()]
		opts.append([ws.mid, "Geht die Mauer ab"])
	if opts.is_empty():
		return _alarm_task(n) if alarm else {}
	var o: Array = opts[(n.idx + (0 if alarm else _rng.randi())) % opts.size()]
	var p: Vector2 = o[0]
	var inward: Vector2 = (home - p).normalized()
	var stand: Vector2 = _stand(p + inward * 2.2)
	var face: Vector2 = stand - inward * 6.0
	var st := {"at": stand, "face": face, "clip": "", "dur": 6.0 if not alarm else 2.0, "text": o[1], "run": alarm}
	if alarm:
		st.loop = true
		st.text = "Bewacht die Basis"
	return {"kind": "guard", "steps": [st]}


func _garden_task(n) -> Dictionary:
	var fl := _nodes_of("blumen")
	if fl.is_empty():
		var d := _door("bunker")
		return {"kind": "work", "steps": [{"at": _stand(d + Vector2(_rng.randf_range(-4, 4), _rng.randf_range(1, 4))), "face": d, "clip": "pick_up", "dur": 3.0, "prop": "c_broom", "text": "Fegt den Platz"}]}
	var s = fl[_rng.randi() % fl.size()]
	return {"kind": "work", "steps": [{"at": _stand(s.mid + Vector2(1.3, 0)), "face": s.mid, "clip": "pick_up", "dur": 3.5, "prop": "c_watering", "text": "Gießt die Blumen"}]}


func _repair_task(n) -> Dictionary:
	var dl := _damaged()
	if dl.is_empty():
		return {}
	# nächstes beschädigtes Gebäude, Handwerker verteilen sich
	dl.sort_custom(func(a, b): return a.mid.distance_squared_to(n.pos) < b.mid.distance_squared_to(n.pos))
	var s = dl[0]
	var taken := 0
	for o in npcs:
		if o != n and o.task.get("kind", "") == "repair" and o.task.get("sid", -1) == int(s.b.id):
			taken += 1
	if taken > 0 and dl.size() > 1:
		s = dl[1]
	var dp := _spot(s, "door")
	var stand := _stand(dp)
	return {"kind": "repair", "sid": int(s.b.id), "steps": [
		{"at": stand, "face": s.mid, "clip": "hammer", "dur": 2.0, "prop": "c_hammer", "loop": true, "text": "Repariert: %s" % String(s.def.name)}]}


func _build_task(n, id: int) -> Dictionary:
	var site := _site_pos(id)
	var stand: Vector2 = nav.free_near(site + (n.pos - site).normalized() * 0.5, 14)
	return {"kind": "build", "site": id, "steps": [
		{"at": stand, "face": site, "clip": "hammer", "dur": 3.0, "prop": "c_hammer", "loop": true, "run": true, "text": "Baut: %s" % String(D.BUILDINGS[String(P.get_building(id).get("key", "wall"))].name)}]}


func _hero_task(n) -> Dictionary:
	var spot: Array = HERO_SPOT.get(n.hero_key, ["bunker", "bunker", "pay", "", "Ruht sich aus"])
	var s = _node_of(spot[0])
	if s == null:
		s = _node_of(spot[1])
	if s == null:
		s = w.bunker_node
	if s == null:
		return {}
	var p := _spot(s, "work_1")
	return {"kind": "work", "steps": [{"at": _stand(p), "face": p, "clip": spot[2], "dur": 6.0, "prop": spot[3], "text": spot[4]}]}


func _alarm_task(n) -> Dictionary:
	var d := _door("bunker")
	return {"kind": "alarm", "steps": [{"at": d, "face": d, "run": true, "hide": true, "text": "Rennt in den Bunker"}]}


func _night_task(n) -> Dictionary:
	var q = _node_of("quartier")
	var d := _door("quartier") if q != null else _door("bunker")
	return {"kind": "night", "steps": [{"at": d, "face": d, "hide": true, "text": "Geht schlafen"}]}


## Pause: Bank, Plausch mit einem anderen Bewohner oder kurz umschauen.
func _pause_task(n) -> Dictionary:
	for b in _benches:
		if b.used.size() < 2:
			var seat: Vector2 = b.p + b.side * (0.45 if b.used.is_empty() else -0.45)
			b.used.append(n)
			return {"kind": "pause", "bench": b, "steps": [{"at": seat, "face": seat + b.face, "clip": "sit", "dur": _rng.randf_range(6.0, 10.0), "text": "Macht Pause auf der Bank"}]}
	for o in npcs:
		if o != n and not o.hidden and o.task.get("kind", "") == "pause" and o.state == "act" and not o.task.has("bench"):
			var at: Vector2 = nav.free_near(o.pos + Vector2(1.2, 0).rotated(_rng.randf() * TAU))
			return {"kind": "pause", "steps": [{"at": at, "face": o.pos, "clip": "wave", "dur": 3.0, "text": "Plaudert mit %s" % o.name}]}
	var home := _door("bunker")
	var q: Vector2 = nav.free_near(home + Vector2(_rng.randf_range(-7, 7), _rng.randf_range(1, 7)))
	return {"kind": "pause", "steps": [{"at": q, "face": q + Vector2(0, 1).rotated(_rng.randf() * TAU), "clip": "", "dur": _rng.randf_range(2.0, 4.0), "text": "Schaut sich um"}]}


## Zwei Bänke vor dem Quartier (oder dem Bunker); stehen sie nach einem Bau im Weg, rücken sie weiter.
func _place_benches() -> void:
	for b in _benches:
		for n in b.used:
			if n.task.get("bench") == b:
				n.task = {}
				n.state = "idle"
		if is_instance_valid(b.n):
			b.n.queue_free()
	_benches.clear()
	if not Models.has_glb("p_bench"):
		return
	var s = _node_of("quartier")
	if s == null:
		s = w.bunker_node
	if s == null:
		return
	var home: Vector2 = w.bunker_node.mid if w.bunker_node != null else Vector2.ZERO
	var d := _spot(s, "door")
	var out: Vector2 = (d - s.mid).normalized() if d.distance_to(s.mid) > 0.1 else Vector2(0, 1)
	for k in 2:
		var p := d + out * 3.2 + out.orthogonal() * (2.4 if k == 0 else -2.4)
		var q: Vector2 = nav.free_near(p, 6)
		# Bank braucht etwas Platz: alle vier Nachbarfelder frei
		var ok := true
		for o in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			if nav.blocked(q + o):
				ok = false
		if not ok:
			continue
		var bn := Models.glb("p_bench")
		w.add_child(bn)
		bn.position = Vector3(q.x, 0, q.y)
		var face := (home - q).normalized() if home.distance_to(q) > 0.5 else out
		bn.rotation.y = atan2(face.x, face.y)
		_benches.append({"n": bn, "p": q, "face": face, "side": face.orthogonal(), "used": []})


## Pause auf der Bank zu Ende: Platz freigeben.
func release(n) -> void:
	for b in _benches:
		b.used.erase(n)
