extends RefCounted
## V6 Paket E – Die Geretteten in der Hauptbasis (Rosa, Professor Moosbach, Knut). Jede Figur ist ein Npc (npc.gd) mit
## eigenem Aussehen (hero_haendlerin, hero_forscher, hero_schmied) und eigenem Tagesablauf wie die Bewohner:
## morgens Frühstück vor dem Bunker, mittags am Lagerfeuer, sonst Arbeit am eigenen Gebäude (Tauschladen, Labor,
## Werkstatt), dazwischen Pausen; nachts schlafen, bei Alarm in den Bunker, nach einem Sieg jubeln.
## Diese Klasse ist für ihre Npc das „Aufgabenbrett“ (dieselben Rückfragen wie npc_board.gd) und nutzt dessen Wegegitter.

const D = preload("res://src/data.gd")
const DG = preload("res://src/data_geschichte.gd")
const Humanoid = preload("res://src/humanoid.gd")
const Npc = preload("res://src/npc.gd")
const Story = preload("res://src/story.gd")

var w: Node3D                        # base_world
var board                            # npc_board.gd
var nav                              # Wegegitter des Bretts
var npcs: Array = []
var _alarm := false
var _night := false
var _rng := RandomNumberGenerator.new()
var _sec := 0.0


func _init(world: Node3D) -> void:
	w = world
	board = w.npc_board
	nav = board.nav
	_rng.randomize()
	sync()


## Gerettete Figuren erscheinen (oder verschwinden, wenn der Spielstand gewechselt wurde).
func sync() -> void:
	var want := Story.rescued_list()
	for n in npcs.duplicate():
		if not want.has(String(n.get_meta("story"))):
			npcs.erase(n)
			if is_instance_valid(n.h):
				n.h.queue_free()
	for k in want:
		var has := false
		for n in npcs:
			if String(n.get_meta("story")) == k:
				has = true
		if not has:
			_spawn(String(k))


func _spawn(key: String) -> Object:
	var h := Humanoid.new()
	w.add_child(h)
	h.build({"kind": key})
	h.scale = Vector3.ONE * D.CHAR_SCALE
	var p: Vector2 = nav.free_near(board._door("bunker") + Vector2(_rng.randf_range(-3, 3), _rng.randf_range(1, 4)))
	h.position = Vector3(p.x, 0, p.y)
	var n = Npc.new(self, h, 100 + DG.RESCUE_ORDER.find(key))
	n.name = String(DG.RESCUES[key].name)
	n.job = "story"
	n.set_meta("story", key)
	n.greet_cd = _rng.randf_range(2.0, 8.0)
	npcs.append(n)
	return n


func find(key: String):
	for n in npcs:
		if String(n.get_meta("story")) == key:
			return n
	return null


# ---------------------------------------------------------------- Bild für Bild
func update(dt: float) -> void:
	if npcs.is_empty() or board == null:
		return
	_sec -= dt
	if _sec <= 0.0:
		_sec = 1.0
		_refresh()
	var hp = w.hero.pos2() if w.hero != null and w.hero.alive and w.hero.visible else null
	var others: Array = board.npcs + npcs
	for n in npcs:
		n.tick(dt, nav, others, hp)
		if not n.hidden:
			n.h.tick(dt)


func _refresh() -> void:
	var alarm := bool(board._alarm)
	if alarm != _alarm:
		_alarm = alarm
		var win: bool = w.ended and bool(w.result.get("win", false))
		for n in npcs:
			if alarm:
				n.give(_alarm_task(n))
			else:
				if n.hidden:
					n.show_at(nav.free_near(board._door("bunker") + Vector2(_rng.randf_range(-3, 3), _rng.randf_range(0.5, 3))))
				n.task = {}
				n.state = "idle"
				if win or w.mode == "peace":
					n.cheer(3.0)
	if _alarm:
		return
	var night := bool(board._night)
	if night != _night:
		_night = night
		for n in npcs:
			if night:
				n.give(_night_task(n))
			elif n.task.get("kind", "") == "night":
				n.show_at(nav.free_near(board._door("quartier") if board._node_of("quartier") != null else board._door("bunker")))
				n.give(_next(n))


# ---------------------------------------------------------------- Aufgaben
func _next(n) -> Dictionary:
	if _alarm:
		return _alarm_task(n)
	if _night:
		return _night_task(n)
	var key := String(n.get_meta("story"))
	var r: Dictionary = DG.RESCUES[key]
	var ph := String(board.phase)
	if ph == "morgen" and n.routine != ph:
		n.routine = ph
		var d: Vector2 = board._door("bunker")
		var q: Vector2 = nav.free_near(d + Vector2(_rng.randf_range(-3, 3), _rng.randf_range(1.5, 3.5)))
		return {"kind": "pause", "steps": [{"at": q, "face": d, "clip": "eat", "dur": 6.0, "text": "Frühstückt vor dem Bunker"}]}
	if ph == "mittag" and n.routine != ph and board._fire_p != Vector2.INF:
		n.routine = ph
		var a := _rng.randf() * TAU
		var q2: Vector2 = nav.free_near(board._fire_p + Vector2(cos(a), sin(a)) * 2.2, 4)
		return {"kind": "pause", "steps": [{"at": q2, "face": board._fire_p, "clip": "warm_hands", "dur": 8.0, "text": "Mittagspause am Lagerfeuer"}]}
	if ph != n.routine and ph in ["tag", "abend"]:
		n.routine = ph
	if _rng.randf() < 0.65:
		var s = board._node_of(String(r.home))
		if s == null:
			s = board._node_of(String(r.home2))
		if s == null:
			s = w.bunker_node
		if s != null:
			var wp: Vector2 = board._spot(s, "work_1")
			return {"kind": "work", "steps": [{"at": board._stand(wp), "face": wp, "clip": String(r.clip), "dur": _rng.randf_range(7.0, 12.0), "text": String(r.work)}]}
	# Pause: umschauen, mit einem Bewohner plaudern
	for o in board.npcs:
		if not o.hidden and o.state == "act" and o.task.get("kind", "") == "pause" and _rng.randf() < 0.5:
			var at: Vector2 = nav.free_near(o.pos + Vector2(1.3, 0).rotated(_rng.randf() * TAU))
			return {"kind": "pause", "steps": [{"at": at, "face": o.pos, "clip": "wave", "dur": 3.0, "text": "Plaudert mit %s" % o.name}]}
	var home: Vector2 = board._door("bunker")
	var q3: Vector2 = nav.free_near(home + Vector2(_rng.randf_range(-8, 8), _rng.randf_range(1, 8)))
	return {"kind": "pause", "steps": [{"at": q3, "face": q3 + Vector2(0, 1).rotated(_rng.randf() * TAU), "clip": "", "dur": _rng.randf_range(2.0, 4.0), "text": "Schaut sich um"}]}


func _alarm_task(_n) -> Dictionary:
	var d: Vector2 = board._door("bunker")
	return {"kind": "alarm", "steps": [{"at": d, "face": d, "run": true, "hide": true, "text": "Rennt in den Bunker"}]}


func _night_task(_n) -> Dictionary:
	var d: Vector2 = board._door("quartier") if board._node_of("quartier") != null else board._door("bunker")
	return {"kind": "night", "steps": [{"at": d, "face": d, "hide": true, "text": "Geht schlafen"}]}


# ---------------------------------------------------------------- Rückfragen der Npc (wie npc_board.gd)
func request(n) -> void:
	n.give(_next(n))


func release(_n) -> void:
	pass


func greet(n) -> void:
	Sfx.play_at("npc_greet", n.h.global_position, -14.0, 1.1, 0.15)


func look_for(_n):
	return null


func gate_near(p: Vector2) -> bool:
	return board.gate_near(p)


func arrived(_n, _st: Dictionary) -> void:
	pass


func on_act(n, st: Dictionary, dt: float) -> void:
	if String(st.get("clip", "")) == "hammer":
		n.acc += dt
		if n.acc >= 0.9:
			n.acc -= 0.9
			Sfx.play_at("anvil_ring", n.h.global_position, -12.0, 1.0, 0.1)
			if w.fx != null:
				w.fx.puff(n.h.global_position + Vector3(0, 1.0, 0.4), Color(1.0, 0.75, 0.3), 4, 0.8)


func keep(_n, _st: Dictionary) -> bool:
	return false


func step_done(n, _st: Dictionary) -> void:
	n.acc = 0.0


# ---------------------------------------------------------------- Antippen
## Tippen auf eine gerettete Figur: Name, Rolle, Tätigkeit, was sie freischaltet, und ein Satz.
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
	var r: Dictionary = DG.RESCUES[String(best.get_meta("story"))]
	var txt := "%s · %s\n%s\n%s\n„%s“" % [best.name, String(r.title), best.doing(), String(r.unlock), preload("res://src/chatter.gd").tap_line(best, board)]
	best.show_sign(txt)
	best.bubble("ui_info")
	Sfx.play("click", -10.0)
	return true
