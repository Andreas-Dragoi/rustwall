extends Node
## Die fünf neuen Fallen (Paket G2, Kapitel 4.1). Werden beim Start einer Flut scharf geschaltet (arm) und wirken
## direkt auf die Gegner der Horde. Stellwerte in D.TRAP:
##   teer      Teergrube (2 × 2): bremst stark; läuft ein Brennender hinein, brennt die Grube 6 s lang (Feuer für alle darin)
##   feder     Federbrett: schleudert leichte Gegner zurück (alle 3 s)
##   koeder    Lockköder: lockt Gegner im Umkreis von 14 m für 8 s an (dreimal je Flut)
##   zaun      Elektrozaun (2 × 1): Blitzschlag alle 1,5 s, kurze Betäubung, 40 Entladungen je Flut
##   eisfalle  Eisfalle: friert Gegner im Umkreis 2,5 s ein, lädt 8 s nach (Eiswesen bleiben unberührt)

const D = preload("res://src/data.gd")
const Models = preload("res://src/models.gd")

var w                                # base_world
var traps: Array = []                # {key, s, c, lv, k, t, cd, uses, fire, active}
var log := {}                        # für Tests: Auslösungen je Falle


## Schaltet alle fertigen Fallen der Basis scharf (einmal je Flut).
static func arm(world) -> Node:
	var n = world.get_node_or_null("Traps2")
	if n == null:
		n = load("res://src/traps2.gd").new()
		n.name = "Traps2"
		world.add_child(n)
	n.setup(world)
	return n


func setup(world) -> void:
	w = world
	traps.clear()
	log.clear()
	var tk := 1.0 + P.cmd_bonus("trap_dmg")
	for id in w.nodes:
		var s: Node3D = w.nodes[id]
		if s.constructing or not D.TRAP.has(s.key):
			continue
		var lv := int(s.b.level) if not s.b.is_empty() else 1
		var tr := {"key": s.key, "s": s, "c": s.mid, "lv": lv, "k": tk * (1.0 + 0.3 * (lv - 1)) * float(w.flood.get("hp", 1.0)),
			"t": 0.0, "cd": 0.0, "uses": int(D.TRAP[s.key].get("uses", 1000000)), "fire": 0.0, "fire_cd": 0.0, "active": 0.0}
		traps.append(tr)


## Gibt es eine Falle in der Nähe (für Tunnelgräber, die im Inneren auftauchen)?
func near(p: Vector2, r: float) -> bool:
	for tr in traps:
		if tr.c.distance_squared_to(p) < (r + float(D.TRAP[tr.key].r)) ** 2:
			return true
	return false


func _physics_process(dt: float) -> void:
	if w == null or not is_instance_valid(w) or not w.is_running() or traps.is_empty():
		return
	var h = w.horde
	for tr in traps:
		tr.cd -= dt
		tr.t -= dt
		tr.fire_cd -= dt
		if tr.t > 0.0:
			continue
		tr.t = 0.2                                          # jede Falle prüft fünfmal je Sekunde
		match String(tr.key):
			"teer":
				_tar(h, tr, dt)
			"feder":
				_spring(h, tr)
			"koeder":
				_bait(h, tr, dt)
			"zaun":
				_fence(h, tr)
			"eisfalle":
				_ice(h, tr)


func _count(key: String) -> void:
	log[key] = int(log.get(key, 0)) + 1


func _tar(h, tr: Dictionary, dt: float) -> void:
	var cfg: Dictionary = D.TRAP.teer
	var c3 := Vector3(tr.c.x, 0, tr.c.y)
	tr.fire -= 0.2
	var any := false
	for e in h.near(tr.c, float(cfg.r)):
		if e.fly or e.stat:
			continue
		any = true
		e.slow = maxf(e.slow, 0.5)
		e.p -= e.v * 0.2 * 0.4                               # zäher Teer: kommt kaum voran
		if e.burn > 0.0 and tr.fire <= 0.0 and tr.fire_cd <= 0.0:
			tr.fire = float(cfg.burn_t)                       # ein Brennender entzündet die Grube
			tr.fire_cd = float(cfg.burn_t) + 8.0
			Sfx.play_at("tar_ignite", c3, -4.0)
			_count("teer_fire")
		if tr.fire > 0.0:
			e.burn = maxf(e.burn, 2.0)
			h.damage(e, float(cfg.burn_dps) * 0.2 * tr.k, Vector2.ZERO, false, true, "feuer")
	if any:
		_count("teer")
	if tr.fire > 0.0 and G.fx != null:
		for k in 2:
			var a := randf() * TAU
			G.fx.puff(c3 + Vector3(cos(a), 0.3, sin(a)) * float(cfg.r) * randf(), Color(1.0, 0.45, 0.1), 3, 1.2)


func _spring(h, tr: Dictionary) -> void:
	if tr.cd > 0.0:
		return
	var cfg: Dictionary = D.TRAP.feder
	var hit := 0
	var away: Vector2 = (tr.c - (w.bunker_node.mid if w.bunker_node != null else Vector2.ZERO)).normalized()
	for e in h.near(tr.c, float(cfg.r)):
		var role := String(D.ENEMIES[e.t].role)
		if e.fly or e.stat or role == "tank" or role == "boss" or role == "miniboss" or e.r > 0.95:
			continue
		h.knock(e, away, float(cfg.push), true)
		e.stun = maxf(e.stun, 0.4)
		h.damage(e, float(cfg.dmg) * tr.k, Vector2.ZERO, false, true, "")
		hit += 1
	if hit > 0:
		tr.cd = float(cfg.cd)
		_count("feder")
		var c3 := Vector3(tr.c.x, 0, tr.c.y)
		Sfx.play_at("trap_spring", c3, -6.0, 1.0, 0.1)
		if G.fx != null:
			G.fx.puff(c3 + Vector3(0, 0.4, 0), Color(0.85, 0.75, 0.55), 8, 1.4)
		var bob = Models.find(tr.s.model, "board") if tr.s != null and tr.s.model != null else null
		if bob != null:
			var tw := bob.create_tween()
			tw.tween_property(bob, "rotation:x", -0.9, 0.08)
			tw.tween_property(bob, "rotation:x", 0.0, 0.5)


func _bait(h, tr: Dictionary, dt: float) -> void:
	var cfg: Dictionary = D.TRAP.koeder
	if tr.active > 0.0:
		tr.active -= 0.2
		if G.fx != null and randf() < 0.4:
			G.fx.ring(Vector3(tr.c.x, 0, tr.c.y), 2.0, Color(1.0, 0.85, 0.3, 0.6), 0.5)
		return
	if tr.uses <= 0 or tr.cd > 0.0:
		return
	var lured := 0
	var r2: float = float(cfg.r) ** 2
	for e in h.list:
		if e.st >= 2 or e.stat or e.p.distance_squared_to(tr.c) > r2:
			continue
		var role := String(D.ENEMIES[e.t].role)
		if role == "boss":
			continue
		e.bait_t = float(cfg.t)
		e.bait_p = tr.c + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * float(cfg.near)
		lured += 1
	if lured > 0:
		tr.uses -= 1
		tr.active = float(cfg.t)
		tr.cd = float(cfg.t) + 4.0
		tr.t = 0.0
		_count("koeder")
		Sfx.play_at("bait_squeak", Vector3(tr.c.x, 0, tr.c.y), -5.0)


func _fence(h, tr: Dictionary) -> void:
	if tr.cd > 0.0 or tr.uses <= 0:
		return
	var cfg: Dictionary = D.TRAP.zaun
	var hit := 0
	var c3 := Vector3(tr.c.x, 1.0, tr.c.y)
	for e in h.near(tr.c, float(cfg.r)):
		if e.fly or e.stat:
			continue
		if hit < 4 and G.fx != null:
			G.fx.lightning(c3, Vector3(e.p.x, 0.6 * e.sc, e.p.y))
		if String(D.ENEMIES[e.t].role) != "boss":
			e.stun = maxf(e.stun, float(cfg.stun))
		h.damage(e, float(cfg.dmg) * tr.k, Vector2.ZERO, false, true, "blitz")
		hit += 1
	if hit > 0:
		tr.cd = float(cfg.cd)
		tr.uses -= 1
		_count("zaun")
		Sfx.play_at("fence_zap", c3, -6.0, 1.0, 0.1)


func _ice(h, tr: Dictionary) -> void:
	if tr.cd > 0.0:
		return
	var cfg: Dictionary = D.TRAP.eisfalle
	var list: Array = h.near(tr.c, float(cfg.r))
	var hit := 0
	for e in list:
		if e.fly or e.stat:
			continue
		var role := String(D.ENEMIES[e.t].role)
		if h.weak_of(e, "eis") > 0.0 and role != "boss":
			e.stun = maxf(e.stun, float(cfg.stun))
			e.slow = maxf(e.slow, float(cfg.stun) + 1.0)
		h.damage(e, float(cfg.dmg) * tr.k, Vector2.ZERO, false, true, "eis")
		hit += 1
	if hit > 0:
		tr.cd = float(cfg.cd)
		_count("eisfalle")
		var c3 := Vector3(tr.c.x, 0, tr.c.y)
		Sfx.play_at("ice_trap", c3, -5.0)
		if G.fx != null:
			G.fx.ring(c3, float(cfg.r), Color(0.75, 0.92, 1.0), 0.7)
			G.fx.puff(c3 + Vector3(0, 0.5, 0), Color(0.85, 0.95, 1.0), 14, 1.6)
