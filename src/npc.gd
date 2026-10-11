extends RefCounted
## Ein Bewohner der Hauptbasis (Paket 2 – Kluge Bewohner).
## Zustandsautomat für eine Aufgabe aus dem Aufgabenbrett (npc_board.gd), die aus Schritten besteht:
##   plan (Weg suchen) -> walk (hingehen) -> turn (zum Arbeitspunkt drehen) -> act (Animation) -> Ergebnis -> nächster Schritt
## Ein Schritt ist ein Dictionary:
##   at: Vector2 Standpunkt (frei)    face: Vector2 Blickziel     clip: String Animation ("" = stehen)
##   dur: float Dauer der Animation   prop: Ding in der Hand während des Schritts   take: Ding, das danach getragen wird
##   drop: bool legt das Getragene ab  hide: bool verschwindet am Ziel (Bunker, Quartier)   run: bool rennt
##   text: String was er gerade tut   loop: bool Schritt wiederholt sich, solange das Brett ihn nicht beendet
## Bewohner weichen einander und dem Helden aus (0,7 m). Ohne Fortschritt über 2 s wird ein neuer Weg gesucht,
## beim dritten Fehlschlag wird er an den Standpunkt versetzt.

const D = preload("res://src/data.gd")
const Models = preload("res://src/models.gd")

const WALK := 2.2                # m/s
const RUN := 5.0
const AVOID := 0.7               # Abstand zu anderen Bewohnern und zum Helden
const STUCK_T := 2.0             # so lange ohne Fortschritt -> neuer Weg
const ARRIVE := 0.18

var board                        # npc_board.gd
var h: Node3D                    # Humanoid
var idx := 0
var name := ""
var job := ""                    # Beruf (Schlüssel aus D.NPC_JOBS)
var hero_key := ""               # freier Held statt Bewohner
var task: Dictionary = {}        # aktuelle Aufgabe: {kind, steps, site, sid, ...}
var si := 0                      # Schritt in der Aufgabe
var state := "idle"              # idle, plan, walk, turn, act, hidden
var path := PackedVector2Array()
var pi := 0
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var act_t := 0.0
var turn_t := 0.0
var best_d := 1.0e9
var stuck_t := 0.0               # Zeit ohne Fortschritt beim Gehen
var fails := 0
var warps := 0                   # wie oft versetzt (für Tests)
var hidden := false
var used_gate := false           # ist (bei Alarm) durch ein Tor gelaufen
var carry := ""                  # getragenes Ding (c_*)
var prop_now := ""               # Ding in der Hand
var night_home := false
var cheer_t := 0.0
var greet_cd := 0.0
var look_t := 0.0
var acc := 0.0                   # Sammler für Wirkungen je Sekunde (Reparatur)
var _bubble: Sprite3D
var _bubble_t := 0.0
var _sign: Label3D
var _sign_t := 0.0
var _nav_v := -1


func _init(b, node: Node3D, i: int) -> void:
	board = b
	h = node
	idx = i
	pos = Vector2(h.position.x, h.position.z)


func job_name() -> String:
	if hero_key != "":
		return String(D.HEROES[hero_key].title)
	return String(D.NPC_JOBS.get(job, "Bewohner"))


func doing() -> String:
	if hidden:
		return "Schläft im Quartier" if task.get("kind", "") == "night" else "Wartet im Bunker"
	if cheer_t > 0.0:
		return "Jubelt"
	var st := step()
	return String(st.get("text", "Schaut sich um"))


func step() -> Dictionary:
	var steps: Array = task.get("steps", [])
	return steps[si] if si < steps.size() else {}


## Steht er gerade sichtbar still mit Absicht (Arbeit, Pause, Drehen, Jubeln, versteckt)?
func is_pausing() -> bool:
	return hidden or cheer_t > 0.0 or state == "act" or state == "turn" or state == "idle" or state == "plan"


## Neue Aufgabe übernehmen (bricht die laufende ab).
func give(t: Dictionary) -> void:
	_end_clip()
	board.release(self)
	task = t
	si = 0
	fails = 0
	acc = 0.0
	if hidden and not bool(t.get("stay_hidden", false)):
		show_at(pos)
	_begin_step()


func _begin_step() -> void:
	var st := step()
	if st.is_empty():
		board.release(self)
		task = {}
		state = "idle"
		return
	_set_prop(String(st.get("prop", carry)))
	best_d = 1.0e9
	stuck_t = 0.0
	if pos.distance_to(st.at) < ARRIVE * 2.0:
		_arrive()
	else:
		state = "plan"


func show_at(p: Vector2) -> void:
	hidden = false
	pos = p
	h.position = Vector3(p.x, 0, p.y)
	h.visible = true


func hide() -> void:
	hidden = true
	state = "hidden"
	_end_clip()
	h.visible = false
	h.move_amount = 0.0
	h.speed_mps = 0.0


func cheer(t: float) -> void:
	if hidden or (task.get("kind", "") == "alarm"):
		return
	cheer_t = t
	h.stop_clip()
	h.play("cheer", true)


func show_sign(text: String) -> void:
	if _sign == null:
		_sign = Label3D.new()
		_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_sign.no_depth_test = true
		_sign.fixed_size = true
		_sign.pixel_size = 0.0016
		_sign.font_size = 26
		_sign.outline_size = 9
		_sign.modulate = Color(1, 0.97, 0.88)
		_sign.outline_modulate = Color(0.12, 0.1, 0.16)
		_sign.position = Vector3(0, 2.15, 0)
		_sign.render_priority = 6
		h.add_child(_sign)
	_sign.text = text
	_sign.visible = true
	_sign_t = 4.5


func bubble(icon: String) -> void:
	if _bubble == null:
		_bubble = Sprite3D.new()
		_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_bubble.no_depth_test = true
		_bubble.pixel_size = 0.0035
		_bubble.position = Vector3(0, 1.75, 0)
		_bubble.render_priority = 5
		h.add_child(_bubble)
	var tex = load("res://icons/%s.png" % icon) if ResourceLoader.exists("res://icons/%s.png" % icon) else null
	if tex == null:
		return
	_bubble.texture = tex
	_bubble.visible = true
	_bubble_t = 2.2


# ---------------------------------------------------------------- Bild für Bild
func tick(dt: float, nav, others: Array, hero_pos) -> void:
	if _sign_t > 0.0:
		_sign_t -= dt
		if _sign_t <= 0.0 and _sign != null:
			_sign.visible = false
	if _bubble_t > 0.0:
		_bubble_t -= dt
		if _bubble_t <= 0.0:
			_bubble.visible = false
	if hidden:
		return
	greet_cd -= dt
	# Held in der Nähe: Kopf drehen, einmal winken, Sprechblase
	if hero_pos != null:
		var dh: float = pos.distance_to(hero_pos)
		if dh < 4.0:
			h.look_target = Vector3(hero_pos.x, 1.5, hero_pos.y)
			look_t = 1.0
			if greet_cd <= 0.0 and task.get("kind", "") != "alarm":
				greet_cd = 25.0
				board.greet(self)
				bubble("ui_heart" if idx % 2 == 0 else "ui_star")
				if state != "walk" and cheer_t <= 0.0 and state != "act":
					h.play("wave", false)
		elif look_t > 0.0:
			look_t -= dt
			if look_t <= 0.0:
				h.look_target = board.look_for(self)
	if cheer_t > 0.0:
		cheer_t -= dt
		h.move_amount = 0.0
		h.speed_mps = 0.0
		if cheer_t <= 0.0:
			h.stop_clip()
			if state == "act":
				_play_step_clip()
		return
	match state:
		"idle":
			board.request(self)
		"plan":
			_plan(nav)
		"walk":
			_walk(dt, nav, others, hero_pos)
		"turn":
			_turn(dt)
		"act":
			_act(dt)
	if state != "walk":
		h.move_amount = 0.0
		h.speed_mps = 0.0


func _plan(nav) -> void:
	var st := step()
	var p: PackedVector2Array = nav.find(pos, st.at)
	if p.size() == 1 and p[0] == Vector2.INF:
		return                       # Suche erst im nächsten Bild (Zeitscheibe)
	_nav_v = nav.version
	if p.is_empty():
		# kein Weg: an den Standpunkt versetzen, damit niemand ewig wartet
		_warp(st.at)
		return
	path = p
	pi = 0
	best_d = 1.0e9
	stuck_t = 0.0
	state = "walk"


func _warp(p: Vector2) -> void:
	warps += 1
	var q: Vector2 = board.nav.free_near(p)
	pos = q
	h.position = Vector3(q.x, 0, q.y)
	fails = 0
	_arrive()


func _walk(dt: float, nav, others: Array, hero_pos) -> void:
	if _nav_v != nav.version:
		state = "plan"               # Basis hat sich geändert: Weg neu suchen
		return
	var st := step()
	var sp: float = RUN if bool(st.get("run", false)) else WALK
	var tgt: Vector2 = path[pi]
	var to := tgt - pos
	var d := to.length()
	if d < ARRIVE + sp * dt:
		pos = tgt if not nav.blocked(tgt) else pos
		pi += 1
		best_d = 1.0e9
		if pi >= path.size():
			h.position = Vector3(pos.x, 0, pos.y)
			_arrive()
			return
		tgt = path[pi]
		to = tgt - pos
		d = to.length()
	var dir := to / maxf(d, 0.001)
	# Ausweichen: die anderen (mit kleinerer Nummer) und der Held haben Vorrang
	var push := Vector2.ZERO
	for o in others:
		if o == self or o.hidden or o.idx > idx:
			continue
		var dd: Vector2 = pos - o.pos
		var l := dd.length()
		if l < AVOID and l > 0.001:
			push += dd / l * (AVOID - l) / AVOID
	if hero_pos != null:
		var dd2: Vector2 = pos - hero_pos
		var l2 := dd2.length()
		if l2 < AVOID + 0.2 and l2 > 0.001:
			push += dd2 / l2 * (AVOID + 0.2 - l2) / AVOID
	var want := dir * sp
	if push != Vector2.ZERO:
		# seitlich ausweichen statt rückwärts
		var side := dir.orthogonal()
		if side.dot(push) < 0.0:
			side = -side
		want = (dir * 0.6 + side * minf(push.length(), 1.0)).normalized() * sp
	vel = vel.lerp(want, minf(1.0, dt * 10.0))
	var np := pos + vel * dt
	if nav.blocked(np):
		var a := pos + Vector2(vel.x, 0) * dt
		var b := pos + Vector2(0, vel.y) * dt
		if not nav.blocked(a):
			np = a
		elif not nav.blocked(b):
			np = b
		else:
			np = pos
	var moved := np.distance_to(pos)
	pos = np
	h.position = Vector3(pos.x, 0, pos.y)
	if vel.length() > 0.2:
		h.rotation.y = lerp_angle(h.rotation.y, atan2(vel.x, vel.y), minf(1.0, dt * 8.0))
	h.speed_mps = maxf(0.01, moved / maxf(dt, 0.0001))
	h.move_amount = sp / 6.4
	# Fortschritt: Abstand zum nächsten Wegpunkt muss sinken
	var nd := pos.distance_to(path[pi])
	if nd < best_d - 0.05:
		best_d = nd
		stuck_t = 0.0
	else:
		stuck_t += dt
		if stuck_t > STUCK_T:
			fails += 1
			stuck_t = 0.0
			if fails >= 3:
				_warp(st.at)
			else:
				state = "plan"
	if board.gate_near(pos):
		used_gate = true


func _arrive() -> void:
	var st := step()
	vel = Vector2.ZERO
	if bool(st.get("hide", false)):
		hide()
		board.arrived(self, st)
		return
	turn_t = 0.0
	state = "turn"


func _turn(dt: float) -> void:
	var st := step()
	var f: Vector2 = st.get("face", st.at)
	var to := f - pos
	turn_t += dt
	if to.length() > 0.05:
		var want := atan2(to.x, to.y)
		h.rotation.y = lerp_angle(h.rotation.y, want, minf(1.0, dt * 9.0))
		if absf(angle_difference(h.rotation.y, want)) > 0.12 and turn_t < 0.7:
			return
	state = "act"
	act_t = float(st.get("dur", 1.0))
	_play_step_clip()
	board.arrived(self, st)


func _play_step_clip() -> void:
	var c := String(step().get("clip", ""))
	if c != "":
		h.play(c, true)


func _act(dt: float) -> void:
	var st := step()
	board.on_act(self, st, dt)
	act_t -= dt
	if act_t > 0.0:
		return
	if bool(st.get("loop", false)) and board.keep(self, st):
		act_t = float(st.get("dur", 1.0))
		return
	_end_clip()
	if st.has("take"):
		carry = String(st.take)
	if bool(st.get("drop", false)):
		carry = ""
	si += 1
	_begin_step()


func _end_clip() -> void:
	h.stop_clip()
	if cheer_t > 0.0:
		cheer_t = 0.0


func _set_prop(k: String) -> void:
	h.carrying = carry != "" and k == carry and k != "c_hammer" and k != "c_watering" and k != "c_broom"
	if k == prop_now:
		return
	prop_now = k
	if k == "" or not Models.has_glb(k):
		h.set_weapon(null, 0)
		return
	var m := Models.glb(k)
	h.set_weapon(m, 0)
