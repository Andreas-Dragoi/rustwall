extends RefCounted
## Klügere Belagerung der Hauptbasis (V6 Paket B, Kapitel 4.2). Lebt nur während einer Flut (base_world.start_flood);
## die Horde ruft tick() in ihrem Logik-Schritt (zählt also in horde.logic_ms) und fragt die Richtungen ab.
##
##  - Brecher (Rolle „tank“, keine Bosse): eigenes Richtungsfeld, in dem Mauerzellen nach ihrem AKTUELLEN Leben kosten
##    (BREACH_WALL_BASE + Leben × BREACH_WALL_HP) und Gebäude sehr teuer sind. Alle Brecher einer Seite folgen demselben
##    Feld und laufen so als Gruppe zur schwächsten erreichbaren Mauerstelle (Lücke > angeschlagenes Holz > Stein > Metall).
##    Das Feld wird alle BREACH_REFRESH Sekunden und nach jedem Mauerbruch in Zeitscheiben neu gerechnet.
##  - Flieger: Feld ohne Hindernisse, in dem jedes Feld in Reichweite einer Luftabwehr AIR_AVOID mehr kostet – gibt es
##    einen Umweg, fliegen sie außen herum. Ohne Luftabwehr fliegen sie wie bisher geradeaus.
##  - Leitern: ab Woche LADDER_WEEK tragen einzelne Schleimlinge eine Leiter (sichtbar über dem Kopf). Stoßen sie auf ein
##    Mauerstück, lehnen sie die Leiter an, klettern langsam hinauf und springen auf der anderen Seite herunter.

const D = preload("res://src/data.gd")
const DB = preload("res://src/data_basis.gd")
const Field = preload("res://src/field.gd")
const AI = preload("res://src/enemy_ai.gd")
const Models = preload("res://src/models.gd")
const MK = preload("res://src/mk.gd")

const S_LADDER := 40                  # Zustand (E.ai_s) eines kletternden Gegners
const LADDER_SCALE := 1.2             # Leiter im Spiel etwas größer als das Modell (2,6 m → 3,1 m)
const LADDER_ELIGIBLE := AI.PRE_MASK | AI.STRIKE_MASK | AI.DMG_MASK | AI.HIT_MASK | AI.DEATH_MASK

var w                                 # base_world
var h                                 # Horde
var breach                            # Field der Brecher
var air                               # Field der Flieger (null ohne Luftabwehr)
var tank := PackedByteArray()         # je Art: 1 = Brecher
var climb_ok := PackedByteArray()     # je Art: 1 = kann eine Leiter tragen
var ladders: Array = []               # {n: Node3D, e: E oder null, t: Restzeit beim Anlehnen, wall: WallSeg}
var budget := 0                       # Leitern, die in dieser Welle noch verteilt werden
var climbs := 0                       # (Test, Rückblick) so oft wurde eine Mauer überklettert
var ladders_given := 0
var air_cells := 0                    # (Test) Felder in Reichweite der Luftabwehr
var _wave := -1
var _t_breach := 0.0
var _t_check := 0.0
var _field_v := -1
var _aa_sig := ""
var _tanks_alive := false
var _rng := RandomNumberGenerator.new()


func _init(world) -> void:
	w = world
	h = world.horde
	_rng.seed = 90210 + int(P.d.week.number)
	tank.resize(D.ENEMIES.size())
	climb_ok.resize(D.ENEMIES.size())
	for t in D.ENEMIES.size():
		var def: Dictionary = D.ENEMIES[t]
		var fl: int = int(h._flags[t]) if t < h._flags.size() else 0
		tank[t] = 1 if (String(def.role) == "tank" and not def.get("boss", false) and not def.get("fly", false)) else 0
		climb_ok[t] = 1 if (String(def.role) == "mass" and not def.get("fly", false) and not def.get("boss", false) and fl & LADDER_ELIGIBLE == 0) else 0
	var f = w.field
	breach = Field.new(Vector2(f.ox, f.oz), f.w, f.h, f.cs)
	breach.solid = f.solid.duplicate()
	breach.water = f.water.duplicate()
	breach.cells = f.cells                       # dieselben Mauern und Gebäude (geteiltes Verzeichnis)
	breach.cost_fn = _breach_cost
	breach.slice_us = DB.BREACH_SLICE_US
	if w.bunker_node != null:
		breach.set_goal(w.bunker_node.mid)
	_field_v = f.rebuilds
	_update_air(true)


## Kosten einer Zelle mit Mauer oder Gebäude für Brecher.
func _breach_cost(s) -> float:
	if is_wall(s) or s.get("gate") == true:
		return DB.BREACH_WALL_BASE + float(s.hp) * DB.BREACH_WALL_HP
	return DB.BREACH_BUILDING + float(s.hp) * 0.02


## Mauerstück (base_world.WallSeg)? Nur Mauerstücke haben eine Bauart „tier“.
static func is_wall(s) -> bool:
	return s != null and s.get("tier") != null


# ---------------------------------------------------------------- Bild für Bild (aus horde._physics_process)
func tick(dt: float) -> void:
	_t_check -= dt
	if _t_check <= 0.0:
		_t_check = 1.0
		_tanks_alive = false
		for e in h.list:
			if e.st != 2 and tank[e.t] == 1:
				_tanks_alive = true
				break
		_update_air(false)
	if w.wave_idx != _wave:
		_wave = w.wave_idx
		budget = 0
		if int(P.d.week.number) >= DB.LADDER_WEEK and not bool(w.flood.get("tutorial", false)):
			budget = mini(int(DB.LADDER_MAX[0]) + int(int(P.d.week.number) / 3), int(DB.LADDER_MAX[1]))
	# Brecher-Feld: nach einem Mauerbruch sofort, sonst alle paar Sekunden (Leben der Mauern ändert sich)
	_t_breach -= dt
	if w.field.rebuilds != _field_v:
		_field_v = w.field.rebuilds
		breach.dirty = true
	if _t_breach <= 0.0 and _tanks_alive:
		_t_breach = DB.BREACH_REFRESH
		breach.dirty = true
	if _tanks_alive or breach.rebuilds == 0:
		breach.update_if_dirty()
	if air != null:
		air.update_if_dirty()
	_tick_ladders(dt)


## Richtung am Boden: Brecher folgen ihrem eigenen Feld, alle anderen dem gemeinsamen.
func ground_dir(e, field) -> Vector2:
	if tank[e.t] == 1 and breach.rebuilds > 0:
		return breach.dir_at(e.p)
	return field.dir_at(e.p)


## Richtung eines Fliegers zum Ziel tg (relativ): mit Luftabwehr über das Umweg-Feld.
func air_dir(e, tg: Vector2) -> Vector2:
	if air != null and air.rebuilds > 0 and tg.length_squared() > 16.0:
		var d: Vector2 = air.dir_at(e.p)
		if d != Vector2.ZERO:
			return d
	return tg.normalized()


## Flieger-Feld neu, wenn sich die Luftabwehr geändert hat (gebaut, zerstört).
func _update_air(force: bool) -> void:
	var aa: Array = []
	for t in w.towers:
		if is_instance_valid(t) and t.key == "aa" and t.active and t.life <= 0.0:
			var s = t.get_parent()
			if s != null and s.get("alive") == false:
				continue
			aa.append(t)
	var sig := ""
	for t in aa:
		sig += "%d,%d;" % [int(t.global_position.x), int(t.global_position.z)]
	if sig == _aa_sig and not force:
		return
	_aa_sig = sig
	if aa.is_empty() or w.bunker_node == null:
		air = null
		air_cells = 0
		return
	var f = w.field
	if air == null:
		air = Field.new(Vector2(f.ox, f.oz), f.w, f.h, f.cs)
		air.slice_us = DB.BREACH_SLICE_US
	air.solid.fill(0)
	air.base.fill(1.0)
	air_cells = 0
	var rng_k: float = w.tower_range_k() if w.has_method("tower_range_k") else 1.0
	for t in aa:
		var c := Vector2(t.global_position.x, t.global_position.z)
		var r: float = float(t.def.range) * rng_k + DB.AIR_MARGIN
		var x0 := maxi(0, int(floor((c.x - r - air.ox) / air.cs)))
		var x1 := mini(air.w - 1, int(floor((c.x + r - air.ox) / air.cs)))
		var z0 := maxi(0, int(floor((c.y - r - air.oz) / air.cs)))
		var z1 := mini(air.h - 1, int(floor((c.y + r - air.oz) / air.cs)))
		for z in range(z0, z1 + 1):
			for x in range(x0, x1 + 1):
				var i: int = x + z * air.w
				if air.center(i).distance_to(c) <= r and air.base[i] < 1.5:
					air.base[i] = 1.0 + DB.AIR_AVOID
					air_cells += 1
	air.set_goal(w.bunker_node.mid)


## (Test, Rückblick) Wohin laufen die Brecher von p aus? Folgt dem Brecher-Feld bis zum ersten Mauerstück oder Gebäude.
func breach_target(p: Vector2):
	if breach.rebuilds == 0:
		breach.rebuild()
	var q := p
	for i in 400:
		var s = w.field.structure_at(q)
		if s != null and not s.passable:
			return s
		var d: Vector2 = breach.dir_at(q)
		if d == Vector2.ZERO:
			return null
		q += d * 0.5
	return null


# ---------------------------------------------------------------- Leitern
## Aus base_world._spawn_one: verteilt Leitern an einzelne Schleimlinge.
func on_spawn(e) -> void:
	if e == null or budget <= 0 or climb_ok[e.t] == 0 or e.elite:
		return
	if _rng.randf() >= (DB.LADDER_CHANCE if G.arg("ladders") == "" else 1.0):     # --ladders=1: jeder darf (Bilder)
		return
	budget -= 1
	ladders_given += 1
	e.ladder = true
	var lad := _free_ladder()
	if lad.is_empty():
		return
	lad.e = e
	lad.wall = null
	lad.t = 0.0
	lad.n.visible = true


func _free_ladder() -> Dictionary:
	for l in ladders:
		if l.e == null and l.t <= 0.0:
			return l
	if ladders.size() >= DB.LADDER_POOL or not Models.has_glb("fx_ladder"):
		return {}
	var n := Models.glb("fx_ladder")
	n.visible = false
	w.add_child(n)
	var l := {"n": n, "e": null, "t": 0.0, "wall": null}
	ladders.append(l)
	return l


func _ladder_of(e) -> Dictionary:
	for l in ladders:
		if l.e == e:
			return l
	return {}


## Ein Leiterträger stößt auf das Mauerstück s: anlegen und klettern (true), oder normal angreifen (false).
func try_climb(e, s) -> bool:
	if not is_wall(s) or not s.alive or s.site:
		return false
	var to: Vector2 = s.mid - e.p
	var axis := Vector2(signf(to.x), 0.0) if absf(to.x) > absf(to.y) else Vector2(0.0, signf(to.y))
	if axis == Vector2.ZERO:
		return false
	var land: Vector2 = s.mid + axis * 2.0
	if w.field.is_solid(land) or w.field.structure_at(land) != null:
		return false                                     # dahinter steht etwas: dann eben angreifen
	e.ladder = false
	e.ai_s = S_LADDER
	e.ai_t = 0.0
	e.ai_v = axis
	e.goal = land
	e.home = e.p
	e.ai_d = [2.4, 2.8, 3.3][clampi(int(s.tier), 0, 2)]  # Höhe der Mauer
	e.st = 0
	e.tgt = null
	e.v = Vector2.ZERO
	e.yaw = atan2(axis.x, axis.y)
	var l := _ladder_of(e)
	if not l.is_empty():
		l.wall = s
		var n: Node3D = l.n
		var foot: Vector2 = s.mid - axis * 1.45
		# Leiter steht unten am Fuß und lehnt um 20° zur Mauer hin (lange Achse des Modells = oben)
		n.transform = Transform3D(Basis(Vector3.UP, atan2(axis.x, axis.y)) * Basis(Vector3.RIGHT, deg_to_rad(20.0)).scaled(Vector3.ONE * LADDER_SCALE), Vector3(foot.x, 0.0, foot.y))
	Sfx.play_at("ladder_place", Vector3(s.mid.x, 0, s.mid.y), -6.0, 1.0, 0.1)
	if G.fx != null:
		G.fx.puff(Vector3(s.mid.x - axis.x * 1.2, 0.3, s.mid.y - axis.y * 1.2), Color(0.75, 0.65, 0.5), 6, 0.8)
	return true


## Aus horde._step für kletternde Gegner (ersetzt Bewegung und Angriff).
func tick_climb(e, dt: float) -> void:
	e.ai_t += dt
	var t0: float = DB.LADDER_TIME[0]
	var t1: float = DB.LADDER_TIME[1]
	var t2: float = DB.LADDER_TIME[2]
	var axis: Vector2 = e.ai_v
	var top: Vector2 = e.goal - axis * 2.0         # Mauermitte
	var foot: Vector2 = top - axis * 1.15
	if e.ai_t < t0:
		e.p = e.home.lerp(foot, clampf(e.ai_t / t0, 0.0, 1.0))
		e.alt = 0.0
	elif e.ai_t < t0 + t1:
		var k: float = (e.ai_t - t0) / t1
		e.p = foot.lerp(top - axis * 0.35, k)
		e.alt = float(e.ai_d) * k
		if int(e.ai_t * 2.5) != int((e.ai_t - dt) * 2.5):
			Sfx.play_at("ladder_climb", Vector3(e.p.x, e.alt, e.p.y), -12.0, 1.0, 0.15)
	elif e.ai_t < t0 + t1 + t2:
		var k2: float = (e.ai_t - t0 - t1) / t2
		e.p = (top - axis * 0.35).lerp(e.goal, k2)
		e.alt = float(e.ai_d) * (1.0 - k2 * k2) + sin(k2 * PI) * 0.4
	else:
		e.p = e.goal
		e.alt = 0.0
		e.ai_s = 0
		e.ai_t = 0.0
		climbs += 1
		if G.fx != null:
			G.fx.puff(Vector3(e.p.x, 0.2, e.p.y), Color(0.75, 0.7, 0.55), 6, 0.8)
		var l := _ladder_of(e)
		if not l.is_empty():
			l.e = null
			l.t = DB.LADDER_STAY
	e.v = Vector2.ZERO
	e.yaw = atan2(axis.x, axis.y)


func _tick_ladders(dt: float) -> void:
	for l in ladders:
		var n: Node3D = l.n
		var e = l.e
		if e != null:
			if e.st == 2:                              # Träger besiegt: Leiter fällt um und bleibt kurz liegen
				l.e = null
				l.t = 2.0
				var fw := Vector3(sin(e.yaw), 0.0, cos(e.yaw))
				n.transform = Transform3D(Basis(Vector3.UP, e.yaw) * Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3.ONE * LADDER_SCALE), Vector3(e.p.x, 0.06, e.p.y) - fw * 1.3 * LADDER_SCALE)
				continue
			if e.ai_s != S_LADDER:
				# getragen: waagerecht über dem Kopf in Laufrichtung, wippt im Schritt
				var top: float = 0.95 * e.sc + 0.25
				var fw2 := Vector3(sin(e.yaw), 0.0, cos(e.yaw))
				var hp3 := Vector3(e.p.x, top + absf(sin(h.time * 7.0 + e.ph)) * 0.08, e.p.y)
				n.transform = Transform3D(Basis(Vector3.UP, e.yaw) * Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3.ONE * LADDER_SCALE), hp3 - fw2 * 1.3 * LADDER_SCALE)
		elif l.t > 0.0:
			l.t -= dt
			if l.t <= 0.0:
				n.visible = false
				l.wall = null
			elif l.wall != null and not l.wall.alive:
				l.t = 0.0
				n.visible = false
				l.wall = null


func clear() -> void:
	for l in ladders:
		if is_instance_valid(l.n):
			l.n.queue_free()
	ladders.clear()
