extends RefCounted
## Die Fähigkeiten: drei je Held (zwei normale, eine Spezialfähigkeit) plus die gewählte
## Kommandanten-Fähigkeit. Plätze: 0 und 1 = Fähigkeiten, 2 = Spezial, 3 = Kommandant.

const D = preload("res://src/data.gd")
const UNLOCK := [1, 5, 10]

var h: Node3D                 # Held
var slots: Array = []         # {key, name, cd, left, locked, why}
var _timers: Array = []       # laufende Dauer-Effekte {t, every, acc, fn}
var _minis: Array = []
var _rng := RandomNumberGenerator.new()


func _init(hero: Node3D) -> void:
	h = hero
	var keys: Array = D.HEROES[h.key].skills
	var cdr := clampf(float(h.m.cdr), 0.0, 0.5)
	for i in 3:
		var def: Dictionary = D.SKILLS[keys[i]]
		var locked: bool = h.level < UNLOCK[i]
		slots.append({"key": keys[i], "name": def.name, "cd": float(def.cd) * (1.0 - cdr), "left": 0.0, "locked": locked, "why": "Ab Heldenstufe %d" % UNLOCK[i]})
	var ck := String(P.d.get("cmd_active", ""))
	if ck != "" and D.CMD_ACTIVES.has(ck) and P.cmd_active_unlocked(ck):
		var cd: Dictionary = D.CMD_ACTIVES[ck]
		slots.append({"key": ck, "name": cd.name, "cd": float(cd.cd) * (1.0 - cdr), "left": 0.0, "locked": false, "why": ""})
	else:
		slots.append({"key": "", "name": "Kommandant", "cd": 1.0, "left": 0.0, "locked": true, "why": "Im Profil wählen (ab Stufe 4)"})


func ratio(slot: int) -> float:
	var s: Dictionary = slots[slot]
	return 1.0 - clampf(s.left / s.cd, 0.0, 1.0)


func ready(slot: int) -> bool:
	var s: Dictionary = slots[slot]
	return not s.locked and s.left <= 0.0


func tick(dt: float) -> void:
	for s in slots:
		if s.left > 0.0:
			s.left = maxf(0.0, s.left - dt)
			if s.left <= 0.0 and h.alive and not s.locked:
				Sfx.play("skill_ready", -13.0, 1.0, 0.2)
	var i := _timers.size() - 1
	while i >= 0:
		var t: Dictionary = _timers[i]
		t.t -= dt
		t.acc += dt
		while t.acc >= t.every:
			t.acc -= t.every
			t.fn.call()
		if t.t <= 0.0:
			_timers.remove_at(i)
		i -= 1


func _every(time: float, every: float, fn: Callable) -> void:
	_timers.append({"t": time, "every": every, "acc": 0.0, "fn": fn})


func use(slot: int) -> bool:
	if slot < 0 or slot >= slots.size():
		return false
	var s: Dictionary = slots[slot]
	if s.locked and not (G.ch("nocd") and s.key != ""):
		P.toast.emit(s.why)
		return false
	if s.left > 0.0 or not h.alive:
		return false
	if not _cast(s.key):
		return false
	s.left = 0.0 if G.ch("nocd") else s.cd
	Sfx.play("sk_" + String(s.key), -5.0)
	h.body.play(["skill_1", "skill_2", "special", "wave"][clampi(slot, 0, 3)])
	P.quest_progress("skills", 1)
	return true


func _ult() -> float:
	return h.skill_scale() * (1.0 + float(h.m.ult))


func _cast(key: String) -> bool:
	var game = G.game
	var horde = G.horde
	var fx = G.fx
	var pp: Vector2 = h.pos2()
	var p3: Vector3 = h.global_position
	var f: Vector2 = h.facing()
	var sc: float = h.skill_scale()
	match key:
		# ---------------- Jona
		"rally":
			game.tower_buff(pp, 20.0, 1.3, 6.0)
			h.rate_k = 1.3
			h.rate_t = 6.0
			fx.ring(p3, 20.0, Color(1.0, 0.85, 0.3), 0.7)
		"roll":
			h.start_dash(0.3, 0.45)
			h.refill()
		"delivery":
			var t = game.spawn_tower("cannon", pp + f * 2.5, 15.0, 1)
			t.dmg_mult = _ult() * 1.6
			fx.ring(p3 + Vector3(f.x, 0, f.y) * 2.5, 4.0, D.C_SKY, 0.5)
		# ---------------- Mika
		"firewall":
			var side := f.orthogonal()
			for i in 5:
				game.add_zone("fire", pp + f * 4.5 + side * (i - 2) * 2.6, 1.8, 5.0, 12.0 * sc * (1.0 + float(h.m.burn)))
		"heatshield":
			h.dr = 0.6
			h.dr_t = 4.0
			h.burn_aura = 4.0
			fx.ring(p3, 3.5, Color(1.0, 0.5, 0.1), 0.5)
		"inferno":
			h.body.hop()
			h.invuln = maxf(h.invuln, 0.6)
			game.blast(p3, 10.0, 110.0 * _ult(), {"burn": 4.0, "knock": 2.5, "element": "feuer"}, Color(1.0, 0.5, 0.1))
		# ---------------- Bruno
		"shieldup":
			h.invuln = 3.0
			for e in horde.in_radius(pp, 9.0):
				e.taunt = 3.0
			fx.ring(p3, 9.0, Color(1.0, 0.8, 0.2), 0.5)
		"patch":
			var n: int = game.repair_around(pp, 10.0, 0.25 * (1.0 + float(h.m.heal)))
			fx.ring(p3, 10.0, Color(0.4, 1.0, 0.5), 0.6)
			if n == 0:
				P.toast.emit("Kein beschädigtes Gebäude in der Nähe")
		"berta":
			var side2 := f.orthogonal()
			for e in horde.list:
				if e.st == 2:
					continue
				var rel: Vector2 = e.p - pp
				var along := rel.dot(f)
				if along > -1.0 and along < 16.0 and absf(rel.dot(side2)) < 3.5:
					horde.damage(e, 60.0 * _ult(), f, false, false, "explosion")
					horde.knock(e, f, 6.0, true)
			for i in 6:
				fx.puff(p3 + Vector3(f.x, 0, f.y) * (2.0 + i * 3.0) + Vector3(0, 0.5, 0), Color("E0A82E"), 14, 2.0)
			G.cam.shake(0.3)
		# ---------------- Ada
		"turret":
			_minis = _minis.filter(func(x): return is_instance_valid(x))
			if _minis.size() >= 2:
				_minis[0].life = 0.01
				_minis.remove_at(0)
			var t2 = game.spawn_tower("mini", pp + f * 1.8, 20.0, 1)
			t2.dmg_mult = sc * 1.2
			_minis.append(t2)
		"overload":
			var best = null
			var bd := 900.0
			for t3 in game.towers:
				if is_instance_valid(t3) and t3.active:
					var dd: float = t3.pos2().distance_squared_to(pp)
					if dd < bd:
						bd = dd
						best = t3
			if best == null:
				P.toast.emit("Kein Turm in der Nähe")
				return false
			best.buff(2.0, 8.0)
		"pieps":
			var d := 16.0 * _ult()
			_every(12.0, 0.25, func():
				var q: Vector2 = h.pos2()
				var e = horde.nearest(q, 13.0)
				if e != null:
					var from: Vector3 = h.global_position + Vector3(-0.6, 2.6, 0)
					if h.body.extra:
						from = h.body.extra.global_position
					fx.lightning(from, Vector3(e.p.x, 0.5 * e.sc, e.p.y))
					horde.damage(e, d, Vector2.ZERO, false, false, "blitz")
					Sfx.play_at("t_mini", from, -15.0, 1.3, 0.1))
		# ---------------- Yuki
		"kiko":
			var e2 = horde.strongest(pp, 30.0)
			if e2 == null:
				return false
			e2.mark = 8.0
			fx.tracer(p3 + Vector3(0, 2.5, 0), Vector3(e2.p.x, 1.0, e2.p.y), Color.WHITE, 0.12, 0.25)
			fx.ring(Vector3(e2.p.x, 0, e2.p.y), 2.5, Color(1.0, 0.3, 0.3), 0.6)
		"smoke":
			h.hidden = true
			h.speed_k = 1.4
			h.speed_t = 4.0
			fx.puff(p3 + Vector3(0, 1, 0), Color(0.8, 0.8, 0.85), 26, 1.5)
		"flock":
			var side3 := f.orthogonal()
			for e in horde.list:
				if e.st == 2:
					continue
				var rel2: Vector2 = e.p - pp
				var along2 := rel2.dot(f)
				if along2 > 0.0 and along2 < 40.0 and absf(rel2.dot(side3)) < 3.0:
					horde.damage(e, 140.0 * _ult(), f, true, false, "kugel")
			for i in 7:
				var o: Vector3 = Vector3(side3.x, 0, side3.y) * (i - 3) * 0.8 + Vector3(0, 1.2 + (i % 3) * 0.3, 0)
				fx.tracer(p3 + o, p3 + o + Vector3(f.x, 0, f.y) * 40.0, Color.WHITE, 0.14, 0.3)
		# ---------------- Greta
		"crackers":
			game.blast(p3, 6.5, 15.0 * sc, {"stun": 2.0, "knock": 0.5}, Color(1.0, 0.9, 0.4))
		"thermos":
			h.heal(h.max_hp * 0.3 * (1.0 + float(h.m.heal)))
			game.repair_around(pp, 8.0, 0.1 * (1.0 + float(h.m.heal)))
			fx.ring(p3, 8.0, Color(0.4, 1.0, 0.5), 0.6)
		"festival":
			var d2 := 45.0 * _ult()
			var center := pp
			_every(4.0, 0.33, func():
				var a := _rng.randf() * TAU
				var q := center + Vector2(cos(a), sin(a)) * sqrt(_rng.randf()) * 11.0
				var cols := [Color(1.0, 0.4, 0.7), Color(0.4, 0.8, 1.0), Color(1.0, 0.9, 0.3), Color(0.6, 1.0, 0.5)]
				game.blast(Vector3(q.x, 0.2, q.y), 3.5, d2, {}, cols[_rng.randi() % 4]))
		# ---------------- Kommandant
		"airstrike":
			var e3 = horde.densest(pp, 40.0, 0.0, 5.0)
			if e3 == null:
				return false
			var c: Vector2 = e3.p
			var d3 := 90.0 * (1.0 + 0.04 * int(P.d.level))
			for i in 5:
				var q2 := c + Vector2(_rng.randf_range(-3.5, 3.5), _rng.randf_range(-3.5, 3.5))
				var to := Vector3(q2.x, 0.1, q2.y)
				game.launch(to + Vector3(-6, 30, -6), to, 0.5 + i * 0.18, 0.0, Color(0.2, 0.2, 0.25), func(): game.blast(to, 4.5, d3))
		"supply":
			h.heal(h.max_hp * 0.6)
			h.refill()
			fx.ring(p3, 3.0, Color(0.4, 1.0, 0.5), 0.6)
		"barrier":
			game.barrier_t = 6.0
			fx.ring(p3, 30.0, D.C_SKY, 0.8)
		"backup":
			for i in 4:
				var a2 := TAU * i / 4.0 + 0.4
				var t4 = game.spawn_tower("mg", pp + Vector2(cos(a2), sin(a2)) * 2.6, 20.0, 1, true)
				t4.dmg_mult = 1.0 + 0.06 * int(P.d.level)
		_:
			return false
	return true
