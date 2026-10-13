extends Node3D
## V4 Waffen-Arsenal: die neuen Schussarten des Helden (hero.gd ruft hierher weiter).
##   bolt    sichtbares Geschoss: Durchschlag (pierce), Abpraller (bounce), Bumerang (ret), Explosion beim Treffer (splash),
##           mehrere im Fächer (count, fan); spin = das Waffenmodell selbst fliegt und dreht sich (Bumerang, Feuerrad, Sterne)
##   beam    Strahl mit Dauerschaden (ramp = steigt beim Halten, chain = springt über)
##   charge  Aufladen (hero.gd zählt), danach Durchschuss (shot = hitscan) oder große Explosion (shot = proj)
##   thrust  Stoß in einer Linie            slam   Sprung ins Ziel und Erdstoß        nova   Ring um den Helden
##   mine    Minen auslegen (mines = höchstens)  turret  Geschütz aufstellen         seek   mehrere zielsuchende Geschosse
## Dazu Erweiterungen der Bogenwürfe (proj): Streubomben (cluster), Pfeilregen (rain), Sog/Gift/Frost-Flächen (zone).
## Alles wird sparsam gezeichnet: Kugeln aus einem Vorrat, das Waffenmodell nur für drehende Wurfwaffen.

const D = preload("res://src/data.gd")
const MK = preload("res://src/mk.gd")
const Models = preload("res://src/models.gd")

const ZONE_COL := {"vortex": Color(0.75, 0.6, 1.0, 0.22), "poison": Color(0.5, 0.95, 0.3, 0.25), "frost": Color(0.6, 0.9, 1.0, 0.25)}
const EL_COL := {"kugel": Color(1.0, 0.92, 0.6), "feuer": Color(1.0, 0.55, 0.15), "wasser": Color(0.5, 0.8, 1.0), "eis": Color(0.7, 0.95, 1.0),
	"blitz": Color(0.75, 0.7, 1.0), "explosion": Color(1.0, 0.7, 0.3), "gift": Color(0.55, 1.0, 0.35)}
const MAX_BOLTS := 40

var hero: Node3D
var bolts: Array = []        # {n, p, y, dir, speed, gone, maxd, pierce, bounce, hit, ret, back, w, d, spin, key}
var mines: Array = []        # {n, p, t, arm, w, d, key}
var zones: Array = []        # {kind, c, r, r2, t, dps, el, tick, n}
var _timers: Array = []      # {t, cb}
var _turrets: Dictionary = {}
var _beam: MeshInstance3D
var _beam_mat: StandardMaterial3D
var _beam_t := 0.0
var _beam_target = null
var _beam_hold := 0.0
var _glow: MeshInstance3D
var _ball: SphereMesh
var _rng := RandomNumberGenerator.new()
var shots := 0               # Zähler für Tests
var hits := 0


## Ton einer Waffe: eigener Name, solange es ihn noch nicht gibt der Ersatz (sound_alt).
static func snd(w: Dictionary) -> String:
	var s := String(w.get("sound", ""))
	if s != "" and Sfx.has(s):
		return s
	return String(w.get("sound_alt", s))


static func el_col(w: Dictionary) -> Color:
	return EL_COL.get(String(w.get("element", "kugel")), Color.WHITE)


func setup(h: Node3D) -> void:
	hero = h
	_rng.randomize()
	_ball = SphereMesh.new()
	_ball.radius = 0.16
	_ball.height = 0.32
	_ball.radial_segments = 8
	_ball.rings = 4
	_beam = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.07
	cm.bottom_radius = 0.07
	cm.height = 1.0
	cm.radial_segments = 6
	cm.rings = 1
	_beam.mesh = cm
	_beam_mat = MK.glow(Color.WHITE, true)
	_beam.material_override = _beam_mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.visible = false
	_beam.top_level = true
	add_child(_beam)
	_glow = MeshInstance3D.new()
	_glow.mesh = _ball
	_glow.material_override = MK.glow(Color(1, 1, 1, 0.8), true)
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow.visible = false
	_glow.top_level = true
	add_child(_glow)


func clear() -> void:
	for b in bolts:
		if b.n != null:
			b.n.queue_free()
	bolts.clear()
	for m in mines:
		if m.n != null:
			m.n.queue_free()
	mines.clear()
	for z in zones:
		if z.n != null:
			z.n.queue_free()
	zones.clear()
	_timers.clear()
	beam_off()
	charge_glow(0.0, Color.WHITE)


func after(t: float, cb: Callable) -> void:
	_timers.append({"t": t, "cb": cb})


# ================================================================= Abschuss
## Neue Schussarten. d = fertiger Schaden je Treffer, pp = Lage des Helden, aim = Richtung, target = Ziel (oder null).
func shoot(w: Dictionary, wkey: String, d: float, pp: Vector2, aim: Vector2, muzzle: Vector3, target) -> void:
	shots += 1
	match String(w.mode):
		"bolt":
			var n := int(w.get("count", 1))
			var fan := float(w.get("fan", 0.0))
			for i in n:
				var a := 0.0
				if n > 1:
					a = deg_to_rad(fan * (float(i) - (n - 1) * 0.5))
				_bolt(w, wkey, d, muzzle, aim.rotated(a))
		"thrust":
			var hits_t: Array = G.horde.ray(pp, aim, float(hero.wrange), 1 + int(w.get("pierce", 0)), 0.55)
			var end := pp + aim * float(hero.wrange)
			for h in hits_t:
				hero._hit(h[1], d, aim)
				hits += 1
			if hits_t.size() > 0:
				end = hits_t[hits_t.size() - 1][1].p
				Sfx.play("w_ball_thud", -9.0, 1.2, 0.08)
			G.fx.tracer(muzzle, Vector3(end.x, muzzle.y * 0.8, end.y), Color(1, 1, 1, 0.7), 0.12, 0.08)
		"slam":
			var to: Vector2 = target.p if target != null else pp + aim * float(hero.wrange) * 0.6
			var dist := minf(pp.distance_to(to), float(hero.wrange))
			var spd: float = float(hero.base_speed) * 3.2
			var t := clampf(dist / spd, 0.08, 0.5)
			hero.dash_dir = aim
			hero.dash_t = t
			hero.invuln = maxf(hero.invuln, t + 0.1)
			after(t + 0.05, func(): _slam_land(w, d))
		"nova":
			_nova(w, d, hero.global_position, float(hero.wrange))
		"mine":
			var tp := pp + aim * minf(float(hero.wrange), 6.0)
			if target != null and pp.distance_to(target.p) < float(hero.wrange):
				tp = target.p
			var to3 := Vector3(tp.x, 0.1, tp.y)
			G.game.launch(muzzle, to3, clampf(muzzle.distance_to(to3) / 18.0, 0.25, 0.6), 1.6, el_col(w), func(): _place_mine(w, wkey, d, tp))
		"turret":
			_turret(w, wkey, pp + aim * 1.8)
		"seek":
			_seek(w, d, pp, aim, muzzle)


func _bolt(w: Dictionary, wkey: String, d: float, muzzle: Vector3, dir: Vector2) -> void:
	if bolts.size() >= MAX_BOLTS:
		return
	var n: Node3D
	if w.get("spin", false):
		n = Models.weapon(wkey)
		n.scale = Vector3.ONE * 1.7
	else:
		var mi := MeshInstance3D.new()
		mi.mesh = _ball
		mi.material_override = MK.glow(el_col(w))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.scale = Vector3(0.8, 0.8, 1.8)
		n = mi
	n.top_level = true
	add_child(n)
	n.global_position = muzzle
	var b := {"n": n, "p": Vector2(muzzle.x, muzzle.z), "y": muzzle.y, "dir": dir, "speed": float(w.get("speed", 20.0)), "gone": 0.0,
		"maxd": float(hero.wrange), "pierce": int(w.get("pierce", 0)), "bounce": int(w.get("bounce", 0)), "hit": {}, "ret": w.get("ret", false),
		"back": false, "w": w, "d": d, "spin": w.get("spin", false), "life": 4.0}
	bolts.append(b)


func _slam_land(w: Dictionary, d: float) -> void:
	if hero == null or not hero.alive:
		return
	var p: Vector3 = hero.global_position
	var opts := _opts(w)
	G.game.blast(p, float(w.get("splash", 3.0)), d, opts, el_col(w))
	G.fx.ring(p, float(w.get("splash", 3.0)) * 1.2, el_col(w), 0.4)
	if w.has("burn"):
		for e in G.horde.in_radius(Vector2(p.x, p.z), float(w.splash)):
			e.burn = maxf(e.burn, float(w.burn))
			e.burn_d = 5.0 * hero.skill_scale()
	G.cam.shake(0.25)
	G.vibrate(25)
	hits += 1


func _nova(w: Dictionary, d: float, p: Vector3, r: float) -> void:
	var opts := _opts(w)
	opts["knock"] = float(w.get("knock", 1.0))
	var c := el_col(w)
	G.horde.explode(Vector2(p.x, p.z), r, d, opts)
	G.fx.ring(p, r, c, 0.45)
	G.fx.ring(p, r * 0.6, Color(c, 0.6), 0.3)
	G.fx.puff(p + Vector3(0, 0.6, 0), c, 14, 1.6)
	if String(w.element) == "blitz":
		for i in 4:
			var a := _rng.randf() * TAU
			G.fx.lightning(p + Vector3(0, 1.0, 0), p + Vector3(cos(a) * r * 0.8, 0.3, sin(a) * r * 0.8))
	hits += 1


func _place_mine(w: Dictionary, wkey: String, d: float, p: Vector2) -> void:
	if not is_inside_tree():
		return
	var mx := int(w.get("mines", 5))
	var own: Array = mines.filter(func(m): return m.key == wkey)
	if own.size() >= mx:
		_mine_boom(own[0])
	var n: Node3D
	if Models.has_glb("b_mine"):
		n = Models.glb("b_mine")
		n.scale = Vector3.ONE * 0.5
	else:
		var mi := MeshInstance3D.new()
		mi.mesh = _ball
		mi.material_override = MK.glow(el_col(w))
		n = mi
	n.top_level = true
	add_child(n)
	n.global_position = Vector3(p.x, 0.02, p.y)
	mines.append({"n": n, "p": p, "t": 30.0, "arm": 0.4, "w": w, "d": d, "key": wkey})
	Sfx.play_at("mine_beep", n.global_position, -14.0, 1.2)


func _mine_boom(m: Dictionary) -> void:
	if not mines.has(m):
		return
	mines.erase(m)
	var w: Dictionary = m.w
	var p := Vector3(m.p.x, 0.1, m.p.y)
	G.game.blast(p, float(w.get("splash", 2.5)), float(m.d), _opts(w), el_col(w))
	if String(w.element) == "blitz":
		G.fx.lightning(p + Vector3(0, 3.0, 0), p)
	if m.n != null:
		m.n.queue_free()
	hits += 1


func _turret(w: Dictionary, wkey: String, p: Vector2) -> void:
	var list: Array = _turrets.get(wkey, [])
	list = list.filter(func(x): return is_instance_valid(x))
	if list.size() >= int(w.get("towers", 2)):
		list[0].life = 0.01
		list.remove_at(0)
	var t = G.game.spawn_tower(String(w.tower), p, float(w.get("life", 18.0)), 1)
	t.dmg_mult = float(w.get("power", 1.0)) * float(hero.dmg) * (1.0 + 0.04 * (int(hero.level) - 1))
	list.append(t)
	_turrets[wkey] = list
	hits += 1


func _seek(w: Dictionary, d: float, pp: Vector2, aim: Vector2, muzzle: Vector3) -> void:
	var n := int(w.get("count", 3))
	var rng := float(hero.wrange)
	var cands: Array = G.horde.in_radius(pp, rng)
	if w.get("elite", false):
		cands.sort_custom(func(a, b): return a.hp > b.hp)
	else:
		cands.sort_custom(func(a, b): return a.p.distance_squared_to(pp) < b.p.distance_squared_to(pp))
	var col := el_col(w)
	for i in n:
		var tp: Vector2
		if cands.size() > 0:
			tp = cands[i % cands.size()].p
		else:
			tp = pp + aim.rotated(_rng.randf_range(-0.5, 0.5)) * minf(rng, 10.0)
		tp += Vector2(_rng.randf_range(-0.4, 0.4), _rng.randf_range(-0.4, 0.4))
		var to := Vector3(tp.x, 0.3, tp.y)
		var w2 := w
		after(0.07 * i, func():
			if not is_inside_tree():
				return
			var mz: Vector3 = hero.body.muzzle.global_position if hero != null and hero.alive else muzzle
			G.game.launch(mz, to, clampf(mz.distance_to(to) / 24.0, 0.25, 0.8), 1.5 + _rng.randf() * 1.5, col, func(): _seek_land(w2, d, to), true))


func _seek_land(w: Dictionary, d: float, to: Vector3) -> void:
	G.game.blast(to, float(w.get("splash", 1.5)), d, _opts(w), el_col(w))
	if String(w.get("zone", "")) == "fire":
		G.game.add_zone("fire", Vector2(to.x, to.z), float(w.get("splash", 1.5)), float(w.get("zone_t", 1.5)), d * 0.3)
	hits += 1


## Wirkungen für Flächenschaden (horde.explode).
func _opts(w: Dictionary) -> Dictionary:
	var o := {"element": String(w.get("element", "explosion"))}
	for k in ["stun", "slow", "root", "burn", "poison", "poison_d", "knock"]:
		if w.has(k):
			o[k] = float(w[k])
	if w.has("chill"):
		o["slow"] = float(w.chill)
	return o


# ================================================================= Bogenwürfe: Streubomben, Pfeilregen, Flächen
func proj_extra(w: Dictionary, to: Vector3, d: float) -> void:
	var c := Vector2(to.x, to.z)
	var col := el_col(w)
	if w.has("mark"):
		for e in G.horde.in_radius(c, float(w.get("splash", 2.0)) + 0.5):
			e.mark = maxf(e.mark, float(w.mark))
	if w.has("cluster"):
		var n := int(w.cluster)
		var spread := float(w.get("splash", 2.0)) * 1.6
		for i in n:
			var a := TAU * float(i) / n + _rng.randf_range(-0.4, 0.4)
			var q := c + Vector2(cos(a), sin(a)) * spread * sqrt(_rng.randf_range(0.2, 1.0))
			var w2 := w
			after(0.08 + 0.07 * i, func(): _bomblet(w2, d, q, col))
	match String(w.get("zone", "")):
		"vortex", "poison", "frost":
			add_zone(String(w.zone), c, float(w.get("splash", 2.5)) + 0.8, float(w.get("zone_t", 3.0)), d * 0.25, String(w.element))


func _bomblet(w: Dictionary, d: float, q: Vector2, col: Color) -> void:
	if not is_inside_tree():
		return
	var p := Vector3(q.x, 0.1, q.y)
	var r := maxf(1.0, float(w.get("splash", 2.0)) * 0.7)
	if w.get("rain", false):
		G.fx.tracer(p + Vector3(-0.6, 6.0, -0.6), p, Color(1, 1, 1), 0.05, 0.12)
		G.fx.puff(p, Color(0.9, 0.85, 0.7), 4, 0.6)
		G.horde.explode(q, r, d, {"element": String(w.element), "knock": 0.2})
		Sfx.play_at("w_bow", p, -16.0, 1.3, 0.06)
	else:
		G.game.blast(p, r, d, _opts(w), col)
	if String(w.get("zone", "")) == "fire":
		G.game.add_zone("fire", q, 1.4, float(w.get("zone_t", 2.0)), d * 0.3)
	hits += 1


func add_zone(kind: String, c: Vector2, r: float, t: float, dps: float, el: String) -> void:
	var col: Color = ZONE_COL[kind]
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r * 0.85
	cm.height = 0.1
	cm.radial_segments = 20
	cm.rings = 1
	m.mesh = cm
	m.material_override = MK.glow(col, true)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.top_level = true
	add_child(m)
	m.global_position = Vector3(c.x, 0.1, c.y)
	zones.append({"kind": kind, "c": c, "r": r, "r2": r * r, "t": t, "dps": dps, "el": el, "tick": 0.0, "n": m})
	Sfx.play_at("w_vortex" if kind == "vortex" else "zone_heal", m.global_position, -10.0, 0.8 if kind == "vortex" else 1.3)


# ================================================================= Strahl und Aufladen
## Strahl: einmal je Bild, solange gefeuert wird. Schaden in Schritten von 0,1 s.
func beam_tick(w: Dictionary, d: float, pp: Vector2, aim: Vector2, muzzle: Vector3, dt: float, rate: float) -> void:
	var rng := float(hero.wrange)
	var pierce := 1 + int(w.get("pierce", 0))
	var hits_b: Array = G.horde.ray(pp, aim, rng, pierce, 0.35)
	var end := Vector3(pp.x + aim.x * rng, muzzle.y * 0.7, pp.y + aim.y * rng)
	var first = hits_b[0][1] if hits_b.size() > 0 else null
	if first != null:
		end = Vector3(hits_b[hits_b.size() - 1][1].p.x, 0.5 * float(hits_b[hits_b.size() - 1][1].sc), hits_b[hits_b.size() - 1][1].p.y)
	if first != _beam_target:
		_beam_target = first
		_beam_hold = 0.0
	elif first != null:
		_beam_hold += dt
	_show_beam(muzzle, end, w)
	_beam_t -= dt
	if _beam_t > 0.0:
		return
	_beam_t = 0.1
	var ramp := 1.0 + float(w.get("ramp", 0.0)) * clampf(_beam_hold / 2.0, 0.0, 1.0)
	var dd := d * float(w.rpm) / 60.0 * 0.1 * rate * ramp
	for h in hits_b:
		var e = h[1]
		_tick_hit(w, e, dd, aim)
	if first != null and int(w.get("chain", 0)) > 0:
		var done: Array = [first]
		var cur = first
		for i in int(w.chain):
			var nxt = null
			var bd := 25.0
			for o in G.horde.in_radius(cur.p, 5.0):
				if not done.has(o):
					var q: float = o.p.distance_squared_to(cur.p)
					if q < bd:
						bd = q
						nxt = o
			if nxt == null:
				break
			done.append(nxt)
			G.fx.lightning(Vector3(cur.p.x, 0.5 * cur.sc, cur.p.y), Vector3(nxt.p.x, 0.5 * nxt.sc, nxt.p.y))
			_tick_hit(w, nxt, dd * 0.7, aim)
			cur = nxt


func _tick_hit(w: Dictionary, e, dd: float, aim: Vector2) -> void:
	if w.has("knock"):
		G.horde.knock(e, aim, float(w.knock) * 0.25)
	if w.has("burn"):
		e.burn = maxf(e.burn, float(w.burn))
		e.burn_d = 5.0 * hero.skill_scale()
	if w.has("leech"):
		hero.heal(dd * float(w.leech))
	G.horde.damage(e, dd, aim, false, true, String(w.get("element", "")))
	hits += 1


func _show_beam(a: Vector3, b: Vector3, w: Dictionary) -> void:
	var v := b - a
	var l := v.length()
	if l < 0.1:
		_beam.visible = false
		return
	var z := v / l
	var x := z.cross(Vector3.UP)
	if x.length_squared() < 0.001:
		x = Vector3.RIGHT
	x = x.normalized()
	var y := x.cross(z).normalized()
	var wob := 1.0 + 0.25 * sin(Time.get_ticks_msec() * 0.03)
	# Zylinder steht entlang Y: Y-Achse auf die Strahlrichtung legen
	_beam.global_transform = Transform3D(Basis(x * wob, z * l, y * wob), a + v * 0.5)
	var c := Color(String(w.get("beam_col", "FFFFFF")))
	c.a = 0.75
	_beam_mat.albedo_color = c
	_beam.visible = true


func beam_off() -> void:
	if _beam != null:
		_beam.visible = false
	_beam_target = null
	_beam_hold = 0.0


## Leuchtkugel an der Mündung beim Aufladen (ratio 0..1; 0 = aus).
func charge_glow(ratio: float, col: Color) -> void:
	if _glow == null:
		return
	if ratio <= 0.0 or hero == null:
		_glow.visible = false
		return
	_glow.visible = true
	_glow.global_position = hero.body.muzzle.global_position
	var s := 0.4 + 1.6 * ratio + (0.15 * sin(Time.get_ticks_msec() * 0.04) if ratio >= 1.0 else 0.0)
	_glow.scale = Vector3.ONE * s
	var c := col
	c.a = 0.45 + 0.4 * ratio
	(_glow.material_override as StandardMaterial3D).albedo_color = c


## Aufgeladener Schuss: k = Ladeanteil (0,3..1), Schaden wächst bis zum Dreifachen.
func charge_fire(w: Dictionary, d: float, k: float, pp: Vector2, aim: Vector2, muzzle: Vector3, target) -> void:
	shots += 1
	var dd := d * lerpf(0.35, 1.0, clampf(k, 0.0, 1.0))
	var col := el_col(w)
	if String(w.get("shot", "hitscan")) == "proj":
		var tp := pp + aim * minf(float(hero.wrange), 12.0)
		if target != null:
			tp = target.p
		var to := Vector3(tp.x, 0.2, tp.y)
		var big := float(w.get("splash", 3.0)) * lerpf(0.6, 1.0, k)
		G.game.launch(muzzle, to, clampf(muzzle.distance_to(to) / 22.0, 0.3, 0.8), 2.5, col, func():
			G.game.blast(to, big, dd, _opts(w), col)
			G.cam.shake(0.3)
			hits += 1, true)
		return
	var pierce := 1 + int(round(int(w.get("pierce", 1)) * lerpf(0.4, 1.0, k)))
	var hits_c: Array = G.horde.ray(pp, aim, float(hero.wrange), pierce, 0.45)
	var end := pp + aim * float(hero.wrange)
	for h in hits_c:
		hero._hit(h[1], dd, aim)
		hits += 1
	if hits_c.size() >= pierce:
		end = hits_c[hits_c.size() - 1][1].p
	var e3 := Vector3(end.x, muzzle.y * 0.7, end.y)
	G.fx.tracer(muzzle, e3, col, 0.12 + 0.12 * k, 0.18)
	G.fx.flash(muzzle, Vector3(aim.x, 0, aim.y), 1.4 + k, true)
	if String(w.element) == "blitz":
		G.fx.lightning(muzzle, e3)


# ================================================================= Ablauf
func _physics_process(dt: float) -> void:
	if G.game == null or G.horde == null or not G.game.is_active():
		return
	var i := _timers.size() - 1
	while i >= 0:
		var tm: Dictionary = _timers[i]
		tm.t -= dt
		if tm.t <= 0.0:
			_timers.remove_at(i)
			tm.cb.call()
		i -= 1
	_tick_bolts(dt)
	_tick_mines(dt)
	_tick_zones(dt)


func _tick_bolts(dt: float) -> void:
	var i := bolts.size() - 1
	while i >= 0:
		var b: Dictionary = bolts[i]
		if _step_bolt(b, dt):
			if b.n != null:
				b.n.queue_free()
			bolts.remove_at(i)
		i -= 1


## true = Geschoss ist fertig.
func _step_bolt(b: Dictionary, dt: float) -> bool:
	b.life -= dt
	if b.life <= 0.0 or hero == null:
		return true
	var w: Dictionary = b.w
	var step: float = b.speed * dt
	var from: Vector2 = b.p
	if b.back:
		var hp: Vector2 = hero.pos2()
		var to: Vector2 = hp - b.p
		if to.length() < maxf(0.8, step):
			return true
		b.dir = to.normalized()
	b.p += b.dir * step
	b.gone += step
	if not b.back:
		b.y = lerpf(b.y, 0.7, minf(1.0, dt * 3.0))
	b.n.global_position = Vector3(b.p.x, b.y, b.p.y)
	if b.spin:
		b.n.rotation = Vector3(0, b.n.rotation.y + dt * 22.0, PI * 0.5)
		# Paket H: Wurfbahn sichtbar – kurze Leuchtspur hinter Bumerang, Feuerrad, Sternen, Anker
		var now3: Vector3 = b.n.global_position
		var tp: Vector3 = b.get("tp", now3)
		if tp.distance_to(now3) > 0.45:
			G.fx.tracer(tp, now3, el_col(w).lightened(0.45), 0.05, 0.22)
			b["tp"] = now3
		elif not b.has("tp"):
			b["tp"] = now3
	else:
		b.n.look_at(b.n.global_position + Vector3(b.dir.x, 0, b.dir.y), Vector3.UP)
	# über die ganze Strecke dieses Schritts prüfen (schnelle Geschosse springen sonst über kleine Gegner)
	var cands: Array = []
	for h in G.horde.ray(from, b.dir, step, 8, 0.4):
		cands.append(h[1])
	for e in cands:
		if b.hit.has(e):
			continue
		b.hit[e] = true
		hero._hit(e, b.d, b.dir)
		hits += 1
		if w.has("splash"):
			G.game.blast(Vector3(b.p.x, 0.4, b.p.y), float(w.splash), b.d * 0.6, _opts(w), el_col(w))
			return true
		if int(b.bounce) > 0:
			var nxt = null
			var bd := 64.0
			for o in G.horde.in_radius(e.p, 8.0):
				if not b.hit.has(o):
					var q: float = o.p.distance_squared_to(e.p)
					if q < bd:
						bd = q
						nxt = o
			if nxt != null:
				b.bounce -= 1
				b.dir = (nxt.p - b.p).normalized()
				b.gone = 0.0
				b.maxd = 9.0
				Sfx.play_at("w_bounce" if Sfx.has("w_bounce") else "shield_clank", b.n.global_position, -14.0, 1.4, 0.05)
				continue
		if b.pierce < 99:
			b.pierce -= 1
			if b.pierce < 0:
				return true
	if b.gone >= b.maxd:
		if b.ret and not b.back:
			b.back = true
			b.hit.clear()
			return false
		return true
	return false


func _tick_mines(dt: float) -> void:
	var i := mines.size() - 1
	while i >= 0:
		var m: Dictionary = mines[i]
		m.t -= dt
		m.arm -= dt
		if m.t <= 0.0:
			if m.n != null:
				m.n.queue_free()
			mines.remove_at(i)
		elif m.arm <= 0.0:
			for e in G.horde.in_radius(m.p, 1.2):
				if not e.fly:
					_mine_boom(m)
					break
		i -= 1


func _tick_zones(dt: float) -> void:
	var i := zones.size() - 1
	while i >= 0:
		var z: Dictionary = zones[i]
		z.t -= dt
		z.tick -= dt
		if z.n != null:
			z.n.rotation.y += dt * (4.0 if z.kind == "vortex" else 0.5)
		if z.tick <= 0.0:
			z.tick = 0.1
			for e in G.horde.in_radius(z.c, z.r):
				match String(z.kind):
					"vortex":
						var to: Vector2 = z.c - e.p
						if to.length() > 0.4:
							G.horde.knock(e, to.normalized(), 0.12, true)
						e.slow = maxf(e.slow, 0.3)
					"poison":
						e.poison = maxf(e.poison, 1.0)
					"frost":
						e.slow = maxf(e.slow, 0.6)
				G.horde.damage(e, z.dps * 0.1, Vector2.ZERO, false, true, String(z.el))
			if _rng.randf() < 0.5:
				var a := _rng.randf() * TAU
				var q: Vector2 = z.c + Vector2(cos(a), sin(a)) * z.r * 0.8
				var col: Color = ZONE_COL[z.kind]
				col.a = 1.0
				G.fx.puff(Vector3(q.x, 0.4, q.y), col, 3, 0.6)
		if z.t <= 0.0:
			if z.n != null:
				z.n.queue_free()
			zones.remove_at(i)
		i -= 1
