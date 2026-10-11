extends Node3D
## Außenbasis eines Gebiets: fester Grundriss (D.OUTPOST_PADS), Bauplätze, fertige Gebäude, Mauern und Türme.
## Der Stand (Stufe, Teilzahlungen je Platz) liegt in P.d.outposts[gebiet]; hier wird er in die Welt gebracht.
## Lage: Mitte C, Richtung s zeigt von der Mitte zur Landestelle (+z im Grundriss), ex steht senkrecht dazu.

const D = preload("res://src/data.gd")
const MK = preload("res://src/mk.gd")
const Models = preload("res://src/models.gd")
const Anim = preload("res://src/anim.gd")
const Pad = preload("res://src/pad.gd")
const Structure = preload("res://src/structure.gd")

signal built(key: String)

var world: Node3D
var area := 0
var ak := ""
var C := Vector2.ZERO
var s := Vector2(0, 1)
var ex := Vector2(1, 0)
var pads := {}                   # Platz -> Pad
var nodes := {}                  # Platz -> fertiges Gebäude (OBuild / Structure) bzw. Array von OWall
var walls: Array = []
var zentrale = null
var depot_pos := Vector2.ZERO
var _grow: Array = []            # {n, t, clip, kind}
var _mm_post: MultiMeshInstance3D
var _mm_link: MultiMeshInstance3D
var _rubble_t := -1.0
var _hp_k := 1.0
var want_dirty := false
var _dirty_t := 0.0


# ================================================================= Gebäude der Außenbasis (eigene, schlanke Art)
class OBuild extends Node3D:
	var key := ""
	var alive := true
	var hp := 100.0
	var max_hp := 100.0
	var mid := Vector2.ZERO
	var radius := 2.0
	var cost := 40.0
	var blocks_player := true
	var passable := false
	var shielded := false
	var gate := false
	var model: Node3D
	var half := Vector2.ONE
	var anims: Array = []
	var _taken := 0.0
	var _window := 0.0
	var _bar: Node3D
	var _bar_t := 0.0
	var _rubble: Node3D

	func hurt(d: float, force := false) -> void:
		if not alive or G.game.barrier_t > 0.0 or G.ch("god_base"):
			return
		d *= G.game.dmg_factor(self)
		if not force:
			var cap := maxf(max_hp * 0.2, 60.0)
			if _taken >= cap:
				return
			d = minf(d, cap - _taken)
			_taken += d
			_window = 1.0
		hp -= d
		Sfx.play_at("struct_hit", global_position, -13.0, 0.9, 0.14)
		if _bar == null:
			_bar = MK.make_bar(clampf(radius * 1.1, 1.6, 4.0), D.C_BAR_BLUE if key == "zentrale" else D.C_BAR_RED, 0.3)
			_bar.position.y = 5.5 if key == "zentrale" else 4.0
			add_child(_bar)
		_bar.visible = true
		_bar_t = 4.0
		MK.set_bar(_bar, hp / max_hp)
		if hp <= 0.0:
			_destroy()

	func repair(ratio: float) -> void:
		if alive:
			hp = minf(max_hp, hp + max_hp * ratio)
			if _bar:
				MK.set_bar(_bar, hp / max_hp)

	func _destroy() -> void:
		alive = false
		hp = 0.0
		model.visible = false
		if _bar:
			_bar.visible = false
		if _rubble == null:
			var st := MK.begin()
			var rng := RandomNumberGenerator.new()
			rng.seed = int(mid.x * 31 + mid.y * 17)
			for i in 9:
				MK.rbox(st, Vector3(rng.randf_range(-1, 1) * radius * 0.7, 0.25, rng.randf_range(-1, 1) * radius * 0.7),
					Vector3(rng.randf_range(0.5, 1.3), 0.5, rng.randf_range(0.5, 1.3)), MK.vary(Color("6A6E80"), 0.15, rng), 0.08, Basis(Vector3.UP, rng.randf() * TAU))
			_rubble = MK.inst(st, self)
		_rubble.visible = true
		G.field.dirty = true
		G.fx.explosion(global_position + Vector3(0, 1.5, 0), radius + 1.0, Color(0.8, 0.7, 0.5))
		Sfx.play_at("struct_destroy", global_position, -2.0)
		G.game.on_structure_destroyed(self)

	func restore() -> void:
		alive = true
		hp = max_hp
		model.visible = true
		if _rubble:
			_rubble.visible = false
		G.field.dirty = true

	func _process(dt: float) -> void:
		_window -= dt
		if _window <= 0.0:
			_taken = 0.0
		if _bar_t > 0.0:
			_bar_t -= dt
			if _bar_t <= 0.0 and _bar:
				_bar.visible = false


## Ein Mauerstück der Außenbasis (gezeichnet über MultiMesh der Außenbasis).
class OWall extends RefCounted:
	var alive := true
	var mid := Vector2.ZERO
	var cost := 30.0
	var blocks_player := true
	var passable := false
	var shielded := false
	var hp := 100.0
	var max_hp := 100.0
	var radius := 1.0
	var dir := Vector2.RIGHT
	var owner_ref
	var _taken := 0.0
	var _stamp := 0.0

	func hurt(d: float, force := false) -> void:
		if not alive or G.game.barrier_t > 0.0 or G.ch("god_base"):
			return
		if not force:
			if G.game.time - _stamp > 1.0:
				_stamp = G.game.time
				_taken = 0.0
			var cap := maxf(max_hp * 0.22, 60.0)
			if _taken >= cap:
				return
			d = minf(d, cap - _taken)
			_taken += d
		hp -= d
		Sfx.play_at("wall_hit_wood", Vector3(mid.x, 0, mid.y), -14.0, 1.0, 0.1)
		if hp <= 0.0:
			alive = false
			hp = 0.0
			G.fx.puff(Vector3(mid.x, 0.8, mid.y), Color(0.7, 0.55, 0.35), 12, 1.2)
			Sfx.play_at("struct_destroy", Vector3(mid.x, 0, mid.y), -8.0, 1.3)
			owner_ref.want_dirty = true          # Richtungsfeld gesammelt neu berechnen (teuer bei 120 × 120)
			owner_ref.redraw_walls()

	func repair(ratio: float) -> void:
		if alive:
			hp = minf(max_hp, hp + max_hp * ratio)


# ================================================================= Aufbau
func setup(w: Node3D, area_idx: int, center: Vector2, to_start: Vector2) -> void:
	world = w
	area = area_idx
	ak = String(D.AREAS[area].key)
	C = center
	s = to_start.normalized()
	ex = Vector2(s.y, -s.x)
	_hp_k = 1.0 + 0.35 * area
	_mm_post = _mm_inst()
	_mm_link = _mm_inst()


func _mm_inst() -> MultiMeshInstance3D:
	var mi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mi.multimesh = mm
	mi.material_override = MK.mat_lin()
	add_child(mi)
	return mi


func to_world(l: Vector2) -> Vector2:
	return C + ex * l.x + s * l.y


func local_def(key: String) -> Dictionary:
	for pd in D.OUTPOST_PADS:
		if String(pd.key) == key:
			return pd
	return {}


## Ausrichtung der Modelle: Vorderseite (+Z) zur Landestelle.
func yaw() -> float:
	return atan2(s.x, s.y)


func level() -> int:
	return P.outpost_level(ak)


## Baut den gespeicherten Stand auf: fertige Plätze stehen sofort, offene bekommen Bauplätze.
func load_state() -> void:
	var lv := level()
	for pd in D.OUTPOST_PADS:
		var pl := int(pd.level)
		var done := P.outpost_pad_done(area, pd)
		if pl <= lv:
			if done or bool(pd.get("must", false)) or pl > 1:
				_build(String(pd.key), true)
			else:
				_make_pad(pd)
		elif pl == 1 or (pl == lv + 1 and lv >= 1):
			if done:
				_build(String(pd.key), true)
			else:
				_make_pad(pd)
	update_locks()
	redraw_walls()


func _make_pad(pd: Dictionary) -> void:
	var key := String(pd.key)
	if pads.has(key):
		return
	var p := Pad.new()
	world.add_child(p)
	var price := P.outpost_pad_price(area, pd)
	var paid := P.outpost_paid(ak, key)
	var ghost := ""
	match String(pd.kind):
		"zentrale":
			ghost = "o_zentrale"
		"depot", "depot_up":
			ghost = "o_depot" if String(pd.kind) == "depot" else ""
		"feuer":
			ghost = "o_feuer"
		"park":
			ghost = "o_parkplatz"
		"special":
			ghost = "o_special_" + ak
		"tower":
			ghost = "t_mg"
		"tor":
			ghost = "b_tor_0"
		"wall":
			ghost = "wall_post_0"
	if pd.has("line"):
		var a := to_world(Vector2(pd.line[0][0], pd.line[0][1]))
		var b := to_world(Vector2(pd.line[1][0], pd.line[1][1]))
		p.setup(pd, price, paid, a.lerp(b, 0.25 if bool(pd.get("gap", false)) else 0.5), yaw(), ghost, a, b)
	else:
		p.setup(pd, price, paid, to_world(Vector2(pd.at[0], pd.at[1])), yaw(), ghost)
	pads[key] = p


## Sind die Bedingungen für diesen Platz erfüllt? Rückgabe: "" oder Grund.
func pad_block(key: String) -> String:
	var pd := local_def(key)
	if key != "zentrale" and int(pd.level) == 1 and not built_ok("zentrale") and not (pads.has("zentrale") and pads.zentrale.rebuild):
		return "Zuerst die Zentrale"
	if bool(pd.get("walls", false)) and not walls_done():
		return "Erst wenn 4 Mauern stehen"
	return ""


func update_locks() -> void:
	for k in pads:
		var why := pad_block(String(k))
		pads[k].set_locked(why != "", why)


func built_ok(key: String) -> bool:
	return nodes.has(key)


func walls_done() -> bool:
	for k in ["wall_n", "wall_o", "wall_s", "wall_w"]:
		if not nodes.has(k):
			return false
	return true


## Alle Pflichtplätze der ersten Stufe stehen.
func mandatory_done() -> bool:
	for pd in D.OUTPOST_PADS:
		if int(pd.level) == 1 and bool(pd.get("must", false)) and not nodes.has(String(pd.key)):
			return false
	return true


## Alle Plätze der nächsten Ausbaustufe bezahlt?
func upgrade_done(lv: int) -> bool:
	var any := false
	for pd in D.OUTPOST_PADS:
		if int(pd.level) == lv:
			any = true
			if not nodes.has(String(pd.key)):
				return false
	return any


func open_pads() -> Array:
	var out: Array = []
	for k in pads:
		var p = pads[k]
		if not p.done:
			out.append(p)
	return out


## Bezahlt: Gebäude entsteht (instant = ohne Wachsen, beim Laden).
func complete_pad(key: String) -> void:
	if pads.has(key):
		var p = pads[key]
		if p.rebuild:
			p.finish()
			p.queue_free()
			pads.erase(key)
			_restore_zentrale()
			return
		p.finish()
		p.queue_free()
		pads.erase(key)
	_build(key, false)
	update_locks()
	built.emit(key)


func _build(key: String, instant: bool) -> void:
	var pd := local_def(key)
	var kind := String(pd.kind)
	match kind:
		"zentrale", "depot", "feuer", "park", "special":
			var b := OBuild.new()
			b.key = kind
			world.add_child(b)
			var m := to_world(Vector2(pd.at[0], pd.at[1]))
			b.mid = m
			b.position = Vector3(m.x, 0, m.y)
			var mname := "o_" + ("parkplatz" if kind == "park" else kind)
			if kind == "special":
				mname = "o_special_" + ak
			b.model = Models.glb(mname, maxi(1, level()) if kind == "special" else 99)
			b.model.rotation.y = yaw()
			b.add_child(b.model)
			b.anims = Anim.collect(b.model)
			world._anims.append_array(b.anims)
			var sz := Vector2(pd.size[0], pd.size[1])
			b.half = Vector2(absf(ex.x) * sz.x + absf(s.x) * sz.y, absf(ex.y) * sz.x + absf(s.y) * sz.y) * 0.5
			b.radius = maxf(b.half.x, b.half.y)
			b.max_hp = float(D.OUTPOST_HP.get(kind, 500.0)) * _hp_k * (1.0 + P.outpost_bonus("wall_hp") * 0.0)
			b.hp = b.max_hp
			b.cost = 60.0 if kind == "zentrale" else 30.0
			b.blocks_player = kind in ["zentrale", "depot", "special"]
			if kind in ["zentrale", "depot", "special"]:
				world.field.add_structure(b, m - b.half + Vector2(0.4, 0.4), m + b.half - Vector2(0.4, 0.4))
			world.structures.append(b)
			nodes[key] = b
			if kind == "zentrale":
				zentrale = b
			if kind == "depot":
				depot_pos = m + s * ((b.half.y if absf(s.y) > 0.5 else b.half.x) + 2.0)
				depot_pos = world.field.center(world.field.idx(depot_pos))
			if not instant:
				_start_grow(b, b.model)
		"wall":
			var a := to_world(Vector2(pd.line[0][0], pd.line[0][1]))
			var bb := to_world(Vector2(pd.line[1][0], pd.line[1][1]))
			var list: Array = []
			var n := int(round(a.distance_to(bb) / D.CELL)) + 1
			var tier := 1 if level() >= 3 else 0
			for i in n:
				var q: Vector2 = a.lerp(bb, float(i) / float(n - 1))
				var ll := Vector2(pd.line[0][0], pd.line[0][1]).lerp(Vector2(pd.line[1][0], pd.line[1][1]), float(i) / float(n - 1))
				if bool(pd.get("gap", false)) and absf(ll.x) < 2.0:
					continue
				var wseg := OWall.new()
				wseg.mid = q
				wseg.dir = (bb - a).normalized()
				wseg.owner_ref = self
				wseg.max_hp = D.OUTPOST_WALL_HP * _hp_k * (1.5 if tier == 1 else 1.0) * (1.0 + P.outpost_bonus("wall_hp"))
				wseg.hp = wseg.max_hp
				wseg.cost = 22.0 + wseg.hp * 0.03
				world.field.add_structure(wseg, q - Vector2(1, 1), q + Vector2(1, 1))
				world.structures.append(wseg)
				walls.append(wseg)
				list.append(wseg)
			nodes[key] = list
			redraw_walls()
			if not instant:
				_grow.append({"walls": true, "t": 0.0})
		"tor":
			var g := Structure.new()
			world.add_child(g)
			var m2 := to_world(Vector2(pd.at[0], pd.at[1]))
			var rot := posmod(int(round(-yaw() / (PI * 0.5))), 4)
			var fp := Vector2i(2, 1) if rot % 2 == 0 else Vector2i(1, 2)
			g.setup({}, "tor", 1 + (1 if level() >= 3 else 0), fp, m2, rot, false)
			g.max_hp *= _hp_k
			g.hp = g.max_hp
			world.field.add_structure(g, m2 - Vector2(fp) + Vector2(0.01, 0.01), m2 + Vector2(fp) - Vector2(0.01, 0.01))
			world.structures.append(g)
			nodes[key] = g
			if not instant:
				g.begin_reveal()
				_grow.append({"n": g, "t": 0.0, "struct": true})
		"tower":
			var t := Structure.new()
			world.add_child(t)
			var m3 := to_world(Vector2(pd.at[0], pd.at[1]))
			var tl := clampi(1 + area + maxi(level() - 1, 0), 1, 10)
			t.setup({}, "mg", tl, Vector2i(2, 2), m3, 0, false)
			t.max_hp *= _hp_k
			t.hp = t.max_hp
			t.tower.dmg_mult *= 1.0 + 0.16 * (int(D.AREAS[area].level) - 1)
			world.towers.append(t.tower)
			world.field.add_structure(t, m3 - Vector2(2, 2) + Vector2(0.01, 0.01), m3 + Vector2(2, 2) - Vector2(0.01, 0.01))
			world.structures.append(t)
			nodes[key] = t
			if not instant:
				t.begin_reveal()
				_grow.append({"n": t, "t": 0.0, "struct": true})
		"special_up":
			nodes[key] = true
			var sp = nodes.get("special")
			if sp != null and not instant:
				_refresh_special(int(String(key).get_slice("_", 1)))
		"walls_up", "depot_up":
			nodes[key] = true
			if kind == "walls_up" and not instant:
				for wv in walls:
					wv.max_hp *= 1.5
					wv.hp = wv.max_hp
				redraw_walls()


## Spezialbau in neuer Stufe zeigen.
func _refresh_special(lv: int) -> void:
	var b = nodes.get("special")
	if b == null or not (b is OBuild):
		return
	b.model.visible = false              # nicht freigeben: die Daueranimationen der Welt verweisen darauf
	b.model = Models.glb("o_special_" + ak, lv)
	b.model.rotation.y = yaw()
	b.add_child(b.model)
	world._anims.append_array(Anim.collect(b.model))
	_start_grow(b, b.model)


func _start_grow(b: Node3D, model: Node3D) -> void:
	var clip := Models.clip_begin(model)
	var h := maxf(Models.height(model), 1.0)
	Models.clip_set(clip, 0.0)
	_grow.append({"n": b, "t": 0.0, "clip": clip, "h": h})


## Mauern neu zeichnen (Pfosten je Stück, Verbindungen zwischen benachbarten Stücken).
func redraw_walls() -> void:
	var tier := 1 if level() >= 3 or nodes.has("walls_3") else 0
	var posts: Array = []
	var links: Array = []
	for k in ["wall_n", "wall_o", "wall_s", "wall_w"]:
		if not nodes.has(k):
			continue
		var list: Array = nodes[k]
		for i in list.size():
			var wv: OWall = list[i]
			if not wv.alive:
				continue
			posts.append(Transform3D(Basis.IDENTITY, Vector3(wv.mid.x, 0, wv.mid.y)))
			if i + 1 < list.size():
				var nx: OWall = list[i + 1]
				if nx.alive and nx.mid.distance_to(wv.mid) < D.CELL + 0.1:
					var mm := (wv.mid + nx.mid) * 0.5
					var d := nx.mid - wv.mid
					links.append(Transform3D(Basis(Vector3.UP, atan2(-d.y, d.x)), Vector3(mm.x, 0, mm.y)))
	_fill_mm(_mm_post, Models.wall_post(tier), posts)
	_fill_mm(_mm_link, Models.wall_link(tier), links)


func _fill_mm(mi: MultiMeshInstance3D, mesh: Mesh, list: Array) -> void:
	var mm := mi.multimesh
	mm.instance_count = 0
	mm.mesh = mesh
	mm.instance_count = list.size()
	for i in list.size():
		mm.set_instance_transform(i, list[i])


# ================================================================= Zentrale in Trümmern
func zentrale_fallen() -> void:
	_rubble_t = D.EXP_RUBBLE_TIME


func _restore_zentrale() -> void:
	if zentrale != null:
		zentrale.restore()
		_start_grow(zentrale, zentrale.model)
	built.emit("zentrale")


func rubble_left() -> float:
	return _rubble_t


func _process(dt: float) -> void:
	_dirty_t -= dt
	if want_dirty and _dirty_t <= 0.0:
		want_dirty = false
		_dirty_t = 1.5
		world.field.dirty = true
	if _rubble_t > 0.0:
		_rubble_t -= dt
		if _rubble_t <= 0.0:
			# Wiederaufbau für den halben Preis
			var pd := local_def("zentrale")
			var p := Pad.new()
			world.add_child(p)
			p.rebuild = true
			p.setup(pd, P.outpost_pad_price(area, pd), {}, zentrale.mid + s * 4.2, yaw(), "")
			pads["zentrale"] = p
			P.toast.emit("Die Zentrale kann für den halben Preis wieder aufgebaut werden.")
	for i in range(_grow.size() - 1, -1, -1):
		var g: Dictionary = _grow[i]
		g.t = float(g.t) + dt
		var k := minf(float(g.t) / D.EXP_GROW_TIME, 1.0)
		if g.has("walls"):
			_mm_post.scale = Vector3(1, maxf(k, 0.05), 1)
			_mm_link.scale = Vector3(1, maxf(k, 0.05), 1)
		elif g.has("struct"):
			if is_instance_valid(g.n):
				g.n.set_progress(k)
		elif is_instance_valid(g.n):
			Models.clip_set(g.clip, g.n.global_position.y + float(g.h) * (0.05 + 1.0 * k))
		if int(g.t * 8.0) != int((g.t - dt) * 8.0) and k < 1.0 and G.fx and g.has("n") and is_instance_valid(g.n):
			G.fx.puff(g.n.global_position + Vector3(randf_range(-1.5, 1.5), 0.3, randf_range(-1.5, 1.5)), Color(0.85, 0.8, 0.7), 4, 0.8)
			Sfx.play_at("pad_hammer", g.n.global_position, -9.0, 1.0, 0.15)
		if k >= 1.0:
			if g.has("clip") and is_instance_valid(g.n):
				Models.clip_set(g.clip, 1000.0)
			_grow.remove_at(i)
