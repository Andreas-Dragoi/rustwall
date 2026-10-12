extends Node3D
## Vulkaninsel (Paket Z): Zonen-Mechanik der Expedition in Gebiet 8. Gehört zu expedition.gd (nur wenn adef.key == "vulkan").
##   Lavaströme   LAVA_STREAMS Ströme im Mittel- und Außenring: ein fester Stamm am Kartenrand, dann zwei Arme. Je Strom fließt
##                immer ein Arm; alle LAVA_SHIFT Sekunden wechselt er (vorher glühen die Risse des anderen Arms LAVA_WARN s auf).
##                Fließende Lava sperrt den Weg (Feld fest wie ein Fels), erkaltete Kruste ist begehbar. Wer im Weg steht,
##                wird verbrannt und zur Seite gestoßen. Beim Vulkanausbruch fließen alle Arme.
##   Hitze-Leiste 0..100: steigt nahe der Lava und in der Tagessonne (die allein höchstens bis HEAT_SUN_CAP), sinkt im Schatten
##                (Felsen, Bäume, Außenbasis) und an kühlen Quellen. Voll = Schaden über Zeit, bis sie unter HEAT_RELEASE fällt.
##   Kühle Quellen HEAT_SPRINGS blaue Quelltöpfe (p_vk_spring) im Mittelring.
##   Asche        beim Ausbruch (exp_world.gd startet ihn): Ascheflocken um die Kamera, mehr Hitze.
## Ablauf: pre_generate() (vor den Kulissen: alle Arme sperren), decor() (Ufersteine, Pflanzen), setup() (Meshes, Startarme,
## Quellen, Anzeige), tick() jedes Bild aus expedition.gd. Zahlen in data_welt.gd.

const D = preload("res://src/data.gd")
const DW = preload("res://src/data_welt.gd")
const MK = preload("res://src/mk.gd")
const Models = preload("res://src/models.gd")
const UI = preload("res://src/ui.gd")
const I18N = preload("res://src/i18n.gd")

const HEAT_SUN_CAP := 55.0
const HEAT_SUN_CAP_ERUPT := 80.0
const R_INNER := 72.0                 # innere Enden der Arme (außerhalb der Karawanen-Runde)
const R_FORK := 94.0
const R_OUTER := 112.0

var ex: Node3D
var rng := RandomNumberGenerator.new()
var streams: Array = []               # {a, trunk: Arm, arms: [Arm, Arm], act, next, warn}
var lava := PackedByteArray()         # 1 = fließende Lava
var own := PackedByteArray()          # 1 = Feld gehört zu einem Arm (war beim Aufbau frei)
var near := PackedByteArray()         # Abstand zur fließenden Lava in Feldern (255 = weit weg)
var heat := 0.0
var hot := false                      # überhitzt (Schaden über Zeit)
var erupt := false
var springs: Array = []               # {p, n}
var log: Array[String] = []           # (Test) was geschehen ist
var shifts := 0
var _hurt_t := 0.0
var _tick_t := 0.0
var _warned := false
var _ash: CPUParticles3D
var _bar: Control
var _layer: CanvasLayer
var _shader: Shader
var _shot_t := 0.0


func _ready() -> void:
	name = "Vulkan"


## Lage der Ströme festlegen und alle Arme sperren, damit keine Bäume, Quellen oder Orte darauf entstehen.
func pre_generate(e: Node3D) -> void:
	ex = e
	rng.seed = hash("rustwall-vulkan|%d" % P.day_index())
	if G.arg("seed") != "":
		rng.seed = int(G.arg("seed")) + 313
	var f = ex.field
	own.resize(f.solid.size())
	lava.resize(f.solid.size())
	near.resize(f.solid.size())
	near.fill(255)
	var lm: Vector2 = ex.welt.lm_p if ex.welt != null else Vector2.INF
	var a0 := rng.randf() * TAU
	for k in DW.LAVA_STREAMS:
		var made := false
		for tries in 24:
			var a := a0 + k * TAU / DW.LAVA_STREAMS + (tries / 2) * 0.13 * (1.0 if tries % 2 == 0 else -1.0)
			var s := _make_stream(a)
			if _stream_ok(s, lm):
				streams.append(s)
				made = true
				break
		if not made and "dbg" in G.arg("vulkan"):
			print("VULKAN Strom %d ohne Platz" % k)
	for s in streams:
		for arm in [s.trunk, s.arms[0], s.arms[1]]:
			arm.cells = _cells_of(arm.pts)
			for i in arm.cells:
				if f.solid[i] == 0:
					own[i] = 1
					f.solid[i] = 1
	f.dirty = true


func _make_stream(a: float) -> Dictionary:
	var dir := Vector2(cos(a), sin(a))
	var side := dir.orthogonal()
	var s0 := dir * R_OUTER
	var fork := dir * R_FORK + side * rng.randf_range(-3.0, 3.0)
	var trunk := _curve(s0, fork, side * rng.randf_range(-4.0, 4.0))
	var arms: Array = []
	for sg in [-1.0, 1.0]:
		var e := Vector2(cos(a + sg * 0.3), sin(a + sg * 0.3)) * (R_INNER + rng.randf_range(0.0, 4.0))
		arms.append({"pts": _curve(fork, e, side * sg * rng.randf_range(3.0, 7.0)), "cells": PackedInt32Array(), "n": null, "mat": null, "heat": 0.0, "warn": 0.0})
	return {"a": a, "trunk": {"pts": trunk, "cells": PackedInt32Array(), "n": null, "mat": null, "heat": 1.0, "warn": 0.0}, "arms": arms,
		"act": rng.randi() % 2, "next": rng.randf_range(DW.LAVA_SHIFT[0], DW.LAVA_SHIFT[1]) * rng.randf_range(0.5, 1.0), "warn": false}


## Gebogener Weg von a nach b (Bogen um bend, dazu ein leichtes Schlängeln), Punkte etwa alle 2 m.
func _curve(a: Vector2, b: Vector2, bend: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := maxi(4, int(a.distance_to(b) / 2.0))
	var side := (b - a).normalized().orthogonal()
	var ph := rng.randf() * TAU
	for i in n + 1:
		var t := float(i) / n
		var p := a.lerp(b, t) + bend * sin(t * PI) + side * sin(t * PI * 3.0 + ph) * 1.2 * sin(t * PI)
		out.append(p)
	return out


func _stream_ok(s: Dictionary, lm: Vector2) -> bool:
	for arm in [s.trunk, s.arms[0], s.arms[1]]:
		for p: Vector2 in arm.pts:
			if absf(p.x) > ex.HALFM - 7.0 or absf(p.y) > ex.HALFM - 7.0:
				return false
			if lm != Vector2.INF and p.distance_to(lm) < 16.0:
				return false
			if p.distance_to(ex.outpost.C) < 20.0 or ex._near_passage(p, 10.0):
				return false
	for o in streams:
		if absf(angle_difference(float(o.a), float(s.a))) < 0.9:
			return false
	return true


## Felder, deren Mitte nah am Weg liegt.
func _cells_of(pts: PackedVector2Array) -> PackedInt32Array:
	var f = ex.field
	var out := PackedInt32Array()
	var hw := DW.LAVA_WIDTH * 0.5 + 0.35
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for p in pts:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	lo -= Vector2(hw + 2.0, hw + 2.0)
	hi += Vector2(hw + 2.0, hw + 2.0)
	var x := lo.x
	while x <= hi.x:
		var z := lo.y
		while z <= hi.y:
			var i: int = f.idx(Vector2(x, z))
			if i >= 0:
				var c: Vector2 = f.center(i)
				if _dist_line(c, pts) < hw and not out.has(i):
					out.append(i)
			z += f.cs
		x += f.cs
	return out


static func _dist_line(p: Vector2, pts: PackedVector2Array) -> float:
	var best := 1.0e9
	for i in pts.size() - 1:
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])))
	return best


## Kulissen der Insel: Basaltbrocken am Ufer der Ströme, Aschegras, Feuerblumen, Fumarolen (vor scatter_commit).
func decor() -> void:
	var f = ex.field
	var r2 := RandomNumberGenerator.new()
	r2.seed = rng.seed + 5
	for s in streams:
		for arm in [s.trunk, s.arms[0], s.arms[1]]:
			var pts: PackedVector2Array = arm.pts
			for i in range(1, pts.size() - 1, 2):
				var d: Vector2 = (pts[i + 1] - pts[i - 1]).normalized().orthogonal()
				for sg in [-1.0, 1.0]:
					if r2.randf() < 0.45:
						var q: Vector2 = pts[i] + d * sg * (DW.LAVA_WIDTH * 0.5 + r2.randf_range(0.5, 1.3))
						if f.in_bounds(q) and lava_cell(q) == false:
							ex.scatter("p_rock_lava_%d" % r2.randi_range(1, 3), Vector3(q.x, -0.15, q.y), r2.randf() * TAU, r2.randf_range(0.3, 0.55))
	for i in [500, 900, 1400][G.quality()]:
		var q2 := Vector2(r2.randf_range(-110.0, 110.0), r2.randf_range(-110.0, 110.0))
		if f.is_solid(q2) or q2.distance_to(ex.outpost.C) < 12.0:
			continue
		var p3 := Vector3(q2.x, 0, q2.y)
		var k := r2.randf()
		if k < 0.55:
			ex.scatter("p_vk_ashgrass", p3, r2.randf() * TAU, r2.randf_range(0.7, 1.3))
		elif k < 0.75:
			ex.scatter("p_vk_firebloom", p3, r2.randf() * TAU, r2.randf_range(0.8, 1.2))
		elif k < 0.8 and q2.length() > 20.0:
			ex.scatter("p_vk_fumarole", p3, r2.randf() * TAU, r2.randf_range(0.8, 1.2))


## Nach dem Aufbau der Karte: Meshes, Startarme, kühle Quellen, Anzeige.
func setup() -> void:
	_shader = load("res://shaders/lava.gdshader")
	for s in streams:
		_mesh(s.trunk)
		for k in 2:
			var arm: Dictionary = s.arms[k]
			_mesh(arm)
			arm.heat = 1.0 if k == s.act else 0.0
			arm.mat.set_shader_parameter("heat", arm.heat)
	_apply_cells()
	_place_springs()
	_make_ash()
	_make_bar()
	log.append("setup:%d" % streams.size())


func _mesh(arm: Dictionary) -> void:
	var pts: PackedVector2Array = arm.pts
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := DW.LAVA_WIDTH * 0.5
	var along := 0.0
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	for i in pts.size():
		var d: Vector2 = (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var o: Vector2 = d.orthogonal() * hw
		var w := hw if i > 0 and i < pts.size() - 1 else hw * 0.8
		o = o.normalized() * w
		if i > 0:
			along += pts[i].distance_to(pts[i - 1])
		var l := Vector3(pts[i].x + o.x, 0.07, pts[i].y + o.y)
		var r := Vector3(pts[i].x - o.x, 0.07, pts[i].y - o.y)
		if i > 0:
			var a0 := along - pts[i].distance_to(pts[i - 1])
			for v in [[prev_l, Vector2(a0, 0)], [prev_r, Vector2(a0, 1)], [r, Vector2(along, 1)], [prev_l, Vector2(a0, 0)], [r, Vector2(along, 1)], [l, Vector2(along, 0)]]:
				st.set_normal(Vector3.UP)
				st.set_uv(v[1])
				st.add_vertex(v[0])
		prev_l = l
		prev_r = r
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("heat", float(arm.heat))
	mat.set_shader_parameter("warn", 0.0)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	arm.n = m
	arm.mat = mat


# ================================================================= Felder
func lava_cell(p: Vector2) -> bool:
	var i: int = ex.field.idx(p)
	return i >= 0 and i < lava.size() and lava[i] == 1


## Abstand zur fließenden Lava in Metern (grob, über das Abstandsfeld; 99 = weit weg).
func lava_dist(p: Vector2) -> float:
	var i: int = ex.field.idx(p)
	if i < 0 or i >= near.size() or near[i] == 255:
		return 99.0
	return float(near[i]) * ex.field.cs


## Für Gegner (lava_bath): liegt fließende Lava höchstens r Meter entfernt?
func near_lava(p: Vector2, r: float) -> bool:
	return lava_dist(p) <= r


func _arm_on(s: Dictionary, k: int) -> bool:
	return k == int(s.act) or erupt


## Setzt die Felder aller Arme passend zum Zustand (fest = fließend) und rechnet das Abstandsfeld neu.
func _apply_cells() -> void:
	var f = ex.field
	var sol: PackedByteArray = ex._outer_solid if not ex._outer_solid.is_empty() else f.solid
	var want := PackedByteArray()
	want.resize(lava.size())
	for s in streams:
		for i in s.trunk.cells:
			want[i] = 1
		for k in 2:
			if _arm_on(s, k):
				for i in s.arms[k].cells:
					want[i] = 1
	var changed := PackedInt32Array()
	for s in streams:
		for arm in [s.trunk, s.arms[0], s.arms[1]]:
			for i in arm.cells:
				if want[i] != lava[i]:
					lava[i] = want[i]
					changed.append(i)
				if own[i] == 1:
					sol[i] = 1 if want[i] == 1 else 0
	if not ex._outer_solid.is_empty():
		ex._outer_solid = sol                # Sperren stehen noch: das Richtungsfeld sieht den Außenring nicht
	else:
		f.solid = sol
		if changed.size() > 0:
			f.dirty = true
	_calc_near()
	if changed.size() > 0:
		_push_out(changed)


func _calc_near() -> void:
	var f = ex.field
	near.fill(255)
	var front := PackedInt32Array()
	for s in streams:
		for arm in [s.trunk, s.arms[0], s.arms[1]]:
			for i in arm.cells:
				if lava[i] == 1 and near[i] != 0:
					near[i] = 0
					front.append(i)
	for step in range(1, 6):
		var nxt := PackedInt32Array()
		for i in front:
			var x: int = i % f.w
			var z: int = i / f.w
			for dz in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var xx: int = x + dx
					var zz: int = z + dz
					if xx < 0 or zz < 0 or xx >= f.w or zz >= f.h:
						continue
					var j: int = xx + zz * f.w
					if near[j] == 255:
						near[j] = step
						nxt.append(j)
		front = nxt


## Wer auf frisch fließender Lava steht, wird verbrannt und zur Seite gestoßen (Held und Gegner).
func _push_out(cells: PackedInt32Array) -> void:
	var f = ex.field
	var hot_set := {}
	for i in cells:
		if lava[i] == 1:
			hot_set[i] = true
	if hot_set.is_empty():
		return
	var h = ex.hero
	if h != null and h.alive and hot_set.has(f.idx(h.pos2())):
		var q := _free_near(h.pos2())
		h.global_position = Vector3(q.x, 0, q.y)
		h.hurt(h.max_hp * 0.2)
		ex.fx.puff(Vector3(q.x, 0.6, q.y), Color(1.0, 0.45, 0.1), 12, 1.4)
		P.toast.emit("Die Lava hat dich erwischt!")
		log.append("lava_hit")
	if ex.horde != null:
		for e in ex.horde.list:
			if e.st != 2 and hot_set.has(f.idx(e.p)):
				e.p = _free_near(e.p)


func _free_near(p: Vector2) -> Vector2:
	var f = ex.field
	for r in range(1, 8):
		for k in 12:
			var q: Vector2 = p + Vector2.from_angle(k * TAU / 12.0) * r * 1.5
			if not f.blocks_player(q) and not lava_cell(q):
				return q
	return p


# ================================================================= Bild für Bild
func tick(dt: float, pp: Vector2) -> void:
	if _shot_t >= 0.0:
		_shot_t += dt
		if _shot_t > 0.5:
			_shot_t = -1.0
			_shot_setup(G.arg("vulkan"))
	_tick_t -= dt
	for s in streams:
		_tick_stream(s, dt, pp)
	if _tick_t <= 0.0:
		_tick_t = 0.1
		_tick_heat(0.1, pp)
	_tick_ash(dt)
	if _bar != null:
		_bar.queue_redraw()


func _tick_stream(s: Dictionary, dt: float, pp: Vector2) -> void:
	for k in 2:
		var arm: Dictionary = s.arms[k]
		var want := 1.0 if _arm_on(s, k) else 0.0
		arm.heat = move_toward(float(arm.heat), want, dt / (1.5 if want > 0.5 else 2.5))
		var w := 0.0
		if bool(s.warn) and k != int(s.act):
			w = clampf(1.0 - float(s.next) / DW.LAVA_WARN, 0.0, 1.0)
		arm.warn = w
		arm.mat.set_shader_parameter("heat", float(arm.heat))
		arm.mat.set_shader_parameter("warn", w)
	if erupt or ex.phase != "explore":
		return
	s.next = float(s.next) - dt
	if not bool(s.warn) and float(s.next) <= DW.LAVA_WARN:
		s.warn = true
		var other: Dictionary = s.arms[1 - int(s.act)]
		var mid: Vector2 = other.pts[other.pts.size() / 2]
		Sfx.play_at("lava_crack", Vector3(mid.x, 0, mid.y), -4.0, 1.0, 0.5)
		if pp.distance_to(mid) < 40.0:
			P.toast.emit("Die Risse glühen auf – gleich sucht sich die Lava einen neuen Weg!")
		log.append("warn")
	if float(s.next) <= 0.0:
		shift(s)


## Der Strom wechselt seinen Arm (auch für Tests und Admin).
func shift(s: Dictionary) -> void:
	s.act = 1 - int(s.act)
	s.warn = false
	s.next = rng.randf_range(DW.LAVA_SHIFT[0], DW.LAVA_SHIFT[1])
	_apply_cells()
	shifts += 1
	var arm: Dictionary = s.arms[int(s.act)]
	var mid: Vector2 = arm.pts[arm.pts.size() / 2]
	Sfx.play_at("lava_shift", Vector3(mid.x, 0, mid.y), -2.0, 1.0, 0.5)
	ex.fx.puff(Vector3(mid.x, 0.8, mid.y), Color(1.0, 0.5, 0.15), 16, 1.6)
	log.append("shift")
	ex.state_changed.emit()


## Vulkanausbruch (exp_world.gd): alle Arme fließen, Asche fällt, die Hitze steigt schneller.
func set_eruption(on: bool) -> void:
	if erupt == on:
		return
	erupt = on
	for s in streams:
		s.warn = false
	_apply_cells()
	log.append("erupt:%s" % on)


# ================================================================= Hitze
func _tick_heat(dt: float, pp: Vector2) -> void:
	var h = ex.hero
	if h == null or not h.alive:
		heat = maxf(0.0, heat - 20.0 * dt)
		hot = false
		return
	var rate := 0.0
	var ld := lava_dist(pp)
	if ld < DW.HEAT_LAVA_R:
		rate += DW.HEAT_LAVA * (1.0 - ld / DW.HEAT_LAVA_R)
	var cap := HEAT_SUN_CAP_ERUPT if erupt else HEAT_SUN_CAP
	if (ex.daytime == "tag" or erupt) and heat < cap:
		rate += DW.HEAT_DAY * (2.0 if erupt else 1.0)
	if erupt:
		rate *= float(DW.EVENTS.vulkan.get("heat_k", 1.0))
	rate *= 1.0 - clampf(P.outpost_bonus("heat_resist"), 0.0, 0.6)     # Obsidianschmiede: Hitzeschutz
	var cool := 0.0
	if in_shade(pp):
		cool += DW.HEAT_COOL
	if at_spring(pp):
		cool += DW.HEAT_SPRING
	if rate <= 0.01 and heat > cap:
		cool += 2.0
	elif rate <= 0.01 and ex.daytime != "tag":
		cool += 1.0
	heat = clampf(heat + (rate - cool) * dt, 0.0, DW.HEAT_MAX)
	if heat >= DW.HEAT_MAX and not hot:
		hot = true
		P.toast.emit("Überhitzt! Such Schatten oder eine kühle Quelle.")
		Sfx.play("heat_overheat", -3.0)
		log.append("overheat")
	elif hot and heat < DW.HEAT_RELEASE:
		hot = false
	if not _warned and heat >= DW.HEAT_WARN:
		_warned = true
		Sfx.play("heat_warn", -6.0)
	elif heat < DW.HEAT_WARN - 15.0:
		_warned = false
	if hot:
		_hurt_t -= dt
		if _hurt_t <= 0.0:
			_hurt_t = 0.5
			h.hurt(h.max_hp * DW.HEAT_DOT * 0.5)
			ex.fx.puff(h.global_position + Vector3(0, 2.0, 0), Color(1.0, 0.5, 0.2), 4, 0.6)
	# Rand der Lava brennt
	if ld < DW.LAVA_EDGE + 0.9:
		h.hurt(h.max_hp * DW.LAVA_DPS * dt)


## Schatten: Fels oder Baum gleich nebenan (nicht Lava), oder unter den Dächern der Außenbasis.
func in_shade(p: Vector2) -> bool:
	if p.distance_to(ex.outpost.C) < 9.0:
		return true
	var f = ex.field
	var sol: PackedByteArray = f.solid
	for o in [Vector2(DW.HEAT_SHADE_R, 0), Vector2(-DW.HEAT_SHADE_R, 0), Vector2(0, DW.HEAT_SHADE_R), Vector2(0, -DW.HEAT_SHADE_R)]:
		var i: int = f.idx(p + o)
		if i >= 0 and sol[i] == 1 and lava[i] == 0 and (own[i] == 0) and absf((p + o).x) < ex.HALFM - 5.0 and absf((p + o).y) < ex.HALFM - 5.0:
			return true
	return false


func at_spring(p: Vector2) -> bool:
	for s in springs:
		if p.distance_to(s.p) < DW.HEAT_SPRING_R:
			return true
	return false


func _place_springs() -> void:
	var taken: Array = [ex.START]
	for i in DW.HEAT_SPRINGS:
		var p = _pick_free(taken)
		if p == null:
			continue
		taken.append(p)
		var n: Node3D = Models.glb("p_vk_spring") if Models.has_glb("p_vk_spring") else Node3D.new()
		n.position = Vector3(p.x, 0, p.y)
		add_child(n)
		springs.append({"p": p, "n": n})


func _pick_free(taken: Array):
	var f = ex.field
	for tries in 80:
		var a := rng.randf() * TAU
		var q := Vector2(cos(a), sin(a)) * rng.randf_range(D.EXP_RING_LAND + 10.0, 95.0)
		var sol: PackedByteArray = ex._outer_solid if not ex._outer_solid.is_empty() else f.solid
		var qi: int = f.idx(q)
		if qi < 0 or sol[qi] == 1 or lava_dist(q) < 8.0:
			continue
		var ok := true
		for o in taken:
			if q.distance_to(o) < 18.0:
				ok = false
		if ok:
			return f.center(f.idx(q))
	return null


## Testbot: zu heiß -> zur nächsten kühlen Stelle (Quelle oder Außenbasis); sonst null.
func bot_cool(pp: Vector2):
	if heat < 85.0 and not hot:
		return null
	var best: Vector2 = ex.outpost.C + ex.outpost.s * 6.0
	var bd := pp.distance_to(best)
	for s in springs:
		var d: float = pp.distance_to(s.p)
		if d < bd:
			bd = d
			best = s.p
	return best


# ================================================================= Asche und Anzeige
func _make_ash() -> void:
	var p := CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.12, 0.03, 0.12)
	p.mesh = bm
	p.amount = [60, 120, 200][G.quality()]
	p.lifetime = 4.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(22, 1, 18)
	p.direction = Vector3(0.3, -1, 0.1)
	p.spread = 25.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0, -0.6, 0)
	p.angular_velocity_min = -180.0
	p.angular_velocity_max = 180.0
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.38, 0.35, 0.34)
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emitting = false
	add_child(p)
	_ash = p


func _tick_ash(_dt: float) -> void:
	if _ash == null:
		return
	_ash.emitting = erupt
	if erupt:
		var focus: Vector3 = ex.cam.focus if ex.cam != null else Vector3.ZERO
		_ash.global_position = focus + Vector3(0, 12, 0)


func _make_bar() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 9
	add_child(_layer)
	_bar = HeatBar.new()
	_bar.vk = self
	_layer.add_child(_bar)


class HeatBar extends Control:
	var vk
	const W := 330.0
	const H := 30.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		position = Vector2.ZERO

	func _draw() -> void:
		if vk == null:
			return
		var vp := get_viewport_rect().size
		var sc: float = clampf(vp.y / 720.0, 0.6, 2.0)
		draw_set_transform(Vector2((vp.x - (W + 36.0) * sc) * 0.5, vp.y - 128.0 * sc), 0.0, Vector2(sc, sc))      # über den Fähigkeiten (oben sitzt die Bossleiste)
		var k: float = clampf(vk.heat / 100.0, 0.0, 1.0)
		var fl: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
		var back := Color(0.06, 0.1, 0.2, 0.86)
		draw_style_box(_box(back, Color(1.0, 0.55, 0.2) if vk.hot else Color("3B7BD0")), Rect2(Vector2(36, 2), Vector2(W, H)))
		var col := Color("FFD23E").lerp(Color("FB3D54"), clampf((k - 0.5) * 2.0, 0.0, 1.0))
		if vk.hot:
			col = col.lerp(Color.WHITE, fl * 0.4)
		if k > 0.01:
			draw_style_box(_box(col, col), Rect2(Vector2(40, 6), Vector2((W - 8.0) * k, H - 8.0)))
		var mk := 40.0 + (W - 8.0) * DW.HEAT_WARN / 100.0
		draw_line(Vector2(mk, 6), Vector2(mk, H - 2), Color(1, 1, 1, 0.5), 2.0)
		var ic: Texture2D = UI.tex("ui_fire") if UI.has_pic("ui_fire") else null
		if ic != null:
			draw_texture_rect(ic, Rect2(Vector2(0, 0), Vector2(34, 34)), false)
		else:
			draw_circle(Vector2(17, 17), 14.0, Color(1.0, 0.5, 0.15))
		var font: Font = UI.font()
		var txt := I18N.t("Hitze" + (" – überhitzt!" if vk.hot else ""))     # Paket S: gezeichneter Text
		draw_string_outline(font, Vector2(50, 25), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, 5, Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(50, 25), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color.WHITE)

	func _box(bg: Color, edge: Color) -> StyleBoxFlat:
		var b := StyleBoxFlat.new()
		b.bg_color = bg
		b.border_color = edge
		b.set_border_width_all(2)
		b.set_corner_radius_all(10)
		return b


## Bilder und Prüfungen (--vulkan=open,near,erupt,hot,shift): Außenbasis fertig, Held an einen Strom, Ausbruch, Hitze.
func _shot_setup(what: String) -> void:
	if what == "":
		return
	var w := what.split(",")
	if "open" in w and ex.phase != "explore":
		ex.admin_outpost_done()
	if "near" in w and streams.size() > 0:
		var s: Dictionary = streams[0]
		var arm: Dictionary = s.arms[int(s.act)]
		var mid: Vector2 = arm.pts[arm.pts.size() / 2]
		var q := _free_near(mid + (-mid).normalized() * 5.0)
		ex.hero.global_position = Vector3(q.x, 0, q.y)
		ex.cam.snap()
	if "shift" in w and streams.size() > 0:
		streams[0].next = DW.LAVA_WARN - 0.5
		streams[0].warn = false
	if "erupt" in w:
		ex.welt.start_event()
	if "hot" in w:
		heat = 92.0
