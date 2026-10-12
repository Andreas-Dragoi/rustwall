extends Node3D
## Lebendige Basis (Auftrag V3, Paket 5): Wiese in drei Schichten, Blumen, Pflanzen im Baufeld,
## Trampelpfade zwischen allen Türen und Toren, Bach, Küste, Laternen und Wegweiser.
##
## Die Wege werden auf dem Baugitter gesucht (Gebäude und Mauern gesperrt, Tore frei) und in eine Bodenmaske
## (256 × 256, R Weg, G Bach, B Sand, A Gebäudefläche) gemalt. Boden und Pflanzen lesen dieselbe Maske:
## der Boden zeichnet dort Sand und Wasser, Gras und Blumen verschwinden auf Wegen und unter Gebäuden.
## Ändert sich die Basis, wird die Maske (verzögert, höchstens alle 0,5 s) neu gerechnet und weich überblendet.

const D = preload("res://src/data.gd")
const MK = preload("res://src/mk.gd")
const Models = preload("res://src/models.gd")

const RES := 256
const MAP_O := Vector2(-66.0, -66.0)
const MAP_S := 132.0
const DIAG := 0.70710678
const COAST_S := 69.0            # Uferlinie: Abstand entlang der Diagonale nach Südwesten
const BEACH_S := 63.0            # ab hier Sand
const BROOK := [Vector2(22, -72), Vector2(33, -61), Vector2(45, -55), Vector2(51, -45), Vector2(53, -31), Vector2(52, -16),
	Vector2(52, 0), Vector2(54, 13), Vector2(60, 21), Vector2(72, 26)]
const BRIDGE := Vector2(52.0, 0.0)
const JETTY_AT := Vector2(-49.0, 44.6)
const N_TUFT := [6000, 12000, 20000]
const N_SMALL := [500, 1000, 1800]
const N_FLOWER := [400, 900, 1600]
const PLANT_TREES := ["p_tree_pine_1", "p_tree_pine_2", "p_tree_pine_3", "p_tree_leaf_1", "p_tree_leaf_2"]
const PLANT_SMALL := ["p_shrub_1", "p_shrub_2", "p_shrub_3", "p_fern", "p_mushroom_1", "p_fern"]
const COL_C := Color("5C9434")   # dunkleres Grün der Wiesenflecken
const COL_D := Color("B4BE40")   # gelbliches Grün der Wiesenflecken
const REBUILD_GAP := 0.5
const BLEND_TIME := 0.8

var w: Node3D                    # base_world.gd
var mask_now: ImageTexture
var mask_old: ImageTexture
var mask_mix := 1.0
var path_cells := PackedByteArray()   # je Baugitter-Feld (GRID_MAX²): 1 = Weg
var flower_spots := PackedVector2Array()
var perch_spots: Array = []     # Vector3: Baumkronen, auf denen Vögel landen
var lamp_spots := PackedVector2Array()
var routes: Array = []          # Liste der Wege (PackedVector2Array in Weltkoordinaten)
var rebuilds := 0
var last_rebuild_ms := 0.0
var lamp_mat: StandardMaterial3D
var _static := PackedByteArray()
var _pending := -1.0
var _since := 99.0
var _rng := RandomNumberGenerator.new()
var _plants: Array = []         # {m, c: Vector2i, yaw, s, off: Vector2}
var _ring: Array = []           # Waldsaum außerhalb des Baufelds (gleiche Einträge)
var _ring_size := -1
var _mm := {}                   # Modell -> MultiMesh (Pflanzen im Baufeld)
var _lamp_mm: MultiMesh
var _lamp_glow_mm: MultiMesh
var _sign_mm: MultiMesh
var _mats: Array = []
var boat: Node3D
var jetty: Node3D
var sea_mat: ShaderMaterial
var felled := {}                 # Paket Welt: gefällte Bäume  "x:y:Modell" -> {t, stump}
var _regrow_t := 5.0


func setup(world: Node3D) -> void:
	w = world
	_rng.seed = 5150
	lamp_mat = StandardMaterial3D.new()
	lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp_mat.albedo_color = Color(1.0, 0.85, 0.45)
	_make_static_mask()
	var img := Image.create_from_data(RES, RES, false, Image.FORMAT_RGBA8, _static)
	mask_now = ImageTexture.create_from_image(img)
	mask_old = mask_now
	_make_meadow()
	_make_plant_meshes()
	_make_lamp_meshes()
	_apply_mask()
	P.buildings_changed.connect(request_rebuild)


func _exit_tree() -> void:
	if P.buildings_changed.is_connected(request_rebuild):
		P.buildings_changed.disconnect(request_rebuild)


## Wege neu berechnen lassen (verzögert, damit mehrere Änderungen zusammen nur einmal rechnen).
func request_rebuild() -> void:
	if _pending < 0.0:
		_pending = maxf(0.05, REBUILD_GAP - _since)


func _process(dt: float) -> void:
	tick(dt)


func tick(dt: float) -> void:
	_since += dt
	_regrow_t -= dt
	if _regrow_t <= 0.0:
		_regrow_t = 5.0
		_regrow()
	if _pending >= 0.0:
		_pending -= dt
		if _pending < 0.0:
			rebuild()
	if boat != null:
		boat.position.y = sin(w.time * 1.1) * 0.09 - 0.05
		boat.rotation.z = sin(w.time * 0.9) * 0.06
		boat.rotation.x = sin(w.time * 0.7 + 1.0) * 0.03
	if mask_mix < 1.0:
		mask_mix = minf(1.0, mask_mix + dt / BLEND_TIME)
		_set_all("mask_mix", mask_mix)


## Kosten eines Schritts für Bewohner (Paket 2): Wege kosten weniger als Wiese.
func path_cost(p: Vector2) -> float:
	var c: Vector2i = w.world_to_cell(p)
	var gm := D.GRID_MAX
	if c.x < 0 or c.y < 0 or c.x >= gm or c.y >= gm:
		return 1.0
	var i := c.x + c.y * gm
	if i >= path_cells.size():
		return 1.0
	return 0.45 if path_cells[i] == 1 else 1.0


func on_path(p: Vector2) -> bool:
	return path_cost(p) < 1.0


## Abstand entlang der Diagonale nach Südwesten (Küste).
static func coast_s(p: Vector2) -> float:
	return (-p.x + p.y) * DIAG


static func shore_at(p: Vector2) -> float:
	var t := (p.x + p.y) * DIAG
	return COAST_S + sin(t * 0.13) * 1.2 + sin(t * 0.31 + 1.0) * 0.6


static func in_sea(p: Vector2, margin := 0.0) -> bool:
	return coast_s(p) > shore_at(p) + margin


## Liegt der Punkt im Bach?
static func in_brook(p: Vector2, margin := 1.8) -> bool:
	for i in BROOK.size() - 1:
		var cp: Vector2 = Geometry2D.get_closest_point_to_segment(p, BROOK[i], BROOK[i + 1])
		if p.distance_to(cp) < margin:
			return true
	return false


# ---------------------------------------------------------------- Maske
func _px(p: Vector2) -> Vector2:
	return (p - MAP_O) / MAP_S * RES


func _make_static_mask() -> void:
	_static.resize(RES * RES * 4)
	_static.fill(0)
	var n := FastNoiseLite.new()
	n.frequency = 0.08
	for y in RES:
		for x in RES:
			var p := MAP_O + Vector2((x + 0.5) / RES * MAP_S, (y + 0.5) / RES * MAP_S)
			var s := coast_s(p)
			if s > BEACH_S - 3.0:
				var b := clampf((s - BEACH_S - n.get_noise_2d(p.x, p.y) * 1.5) / 2.5, 0.0, 1.0)
				_static[(x + y * RES) * 4 + 2] = int(b * 255.0)
	_stamp_line(_static, PackedVector2Array(BROOK), 1.9, 1, 0.55)
	# Uferstreifen unter dem Steg
	_stamp_line(_static, PackedVector2Array([JETTY_AT, JETTY_AT + Vector2(-2, 2)]), 2.5, 2, 0.5)


## Malt einen weichen Strich (Maximum) in einen Kanal. soft = Anteil des weichen Randes am Radius.
func _stamp_line(buf: PackedByteArray, pts: PackedVector2Array, radius: float, ch: int, soft := 0.5, wobble := 0.0) -> void:
	var rp := radius / MAP_S * RES
	var step := maxf(rp * 0.6, 0.6)
	for i in pts.size() - 1:
		var a := _px(pts[i])
		var b := _px(pts[i + 1])
		var ln := a.distance_to(b)
		var nseg := maxi(1, int(ceil(ln / step)))
		for k in nseg + 1:
			var c := a.lerp(b, float(k) / nseg)
			var r := rp * (1.0 + wobble * sin(c.x * 0.7 + c.y * 0.43))
			var x0 := maxi(0, int(c.x - r - 1))
			var x1 := mini(RES - 1, int(c.x + r + 1))
			var y0 := maxi(0, int(c.y - r - 1))
			var y1 := mini(RES - 1, int(c.y + r + 1))
			for yy in range(y0, y1 + 1):
				for xx in range(x0, x1 + 1):
					var d := Vector2(xx + 0.5, yy + 0.5).distance_to(c)
					if d >= r:
						continue
					var v := int(clampf((r - d) / (r * soft), 0.0, 1.0) * 255.0)
					var idx := (xx + yy * RES) * 4 + ch
					if v > buf[idx]:
						buf[idx] = v


func _fill_rect(buf: PackedByteArray, a: Vector2, b: Vector2, ch: int) -> void:
	var pa := _px(a)
	var pb := _px(b)
	for yy in range(maxi(0, int(pa.y)), mini(RES - 1, int(pb.y)) + 1):
		for xx in range(maxi(0, int(pa.x)), mini(RES - 1, int(pb.x)) + 1):
			buf[(xx + yy * RES) * 4 + ch] = 255


func _set_all(param: String, v) -> void:
	if w.ground_mat != null:
		w.ground_mat.set_shader_parameter(param, v)
	for m in MK.wind3_mats():
		m.set_shader_parameter(param, v)


func _apply_mask() -> void:
	_set_all("mask_a", mask_old)
	_set_all("mask_b", mask_now)
	_set_all("mask_mix", mask_mix)
	_set_all("map_origin", MAP_O)
	_set_all("map_size", Vector2(MAP_S, MAP_S))
	_set_all("col_a", w.theme.ground)
	_set_all("col_b", w.theme.ground2)
	_set_all("col_c", COL_C)
	_set_all("col_d", COL_D)
	if w.ground_mat != null:
		_set_all("noise_tex", w.ground_mat.get_shader_parameter("noise_tex"))
		w.ground_mat.set_shader_parameter("patches", 1.0)
		w.ground_mat.set_shader_parameter("use_mask", 1.0)


# ---------------------------------------------------------------- Wege
## Sucht die Wege, malt die Maske neu, setzt Laternen, Wegweiser und Pflanzen.
func rebuild() -> void:
	var t0 := Time.get_ticks_usec()
	_since = 0.0
	_pending = -1.0
	rebuilds += 1
	var gm := D.GRID_MAX
	var n := gm * gm
	var occ := P.occupancy()
	var keys := {}
	for b in P.d.buildings:
		keys[int(b.id)] = String(b.key)
	var cost := PackedFloat32Array()
	cost.resize(n)
	cost.fill(1.0)
	var blocked := PackedByteArray()
	blocked.resize(n)
	for k in occ:
		var x := int(k) % 64
		var y := int(k) / 64
		if x >= gm or y >= gm:
			continue
		var key: String = keys.get(int(occ[k]), "")
		if key == "tor":
			continue
		var cat := String(D.BUILDINGS[key].cat) if D.BUILDINGS.has(key) else ""
		if cat == "trap":
			cost[x + y * gm] = 5.0
		else:
			blocked[x + y * gm] = 1
	for i in n:
		if blocked[i] == 1:
			cost[i] = -1.0
			continue
		var x := i % gm
		var y := i / gm
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var xx := x + dx
				var yy := y + dy
				if xx >= 0 and yy >= 0 and xx < gm and yy < gm and blocked[xx + yy * gm] == 1:
					cost[i] = maxf(cost[i], 1.7)
	# Ziele: Bunker zuerst, dann alle Gebäude mit Tür und alle Tore (nach Abstand zum Bunker)
	var targets: Array = []
	var start := -1
	var start_pt := Vector2.ZERO
	var outs: Array = []
	for id in w.nodes:
		var s: Node3D = w.nodes[id]
		if not is_instance_valid(s):
			continue
		var cat := String(s.def.cat)
		if s.key == "tor":
			var c: Vector2i = w.world_to_cell(s.mid)
			var ci := _cell_ok(c, blocked)
			if ci >= 0:
				var along := Vector2(0, 1) if s.size.x >= s.size.y else Vector2(1, 0)
				var away: Vector2 = s.mid - (w.bunker_node.mid if w.bunker_node != null else Vector2.ZERO)
				if along.dot(away) < 0.0:
					along = -along
				targets.append({"cell": ci, "pt": s.mid, "d": s.mid.length()})
				outs.append([s.mid, along])
			continue
		if not (cat in ["core", "prod", "special"]):
			continue
		var dp := door_point(s)
		var ci2 := _door_cell(dp[0], dp[1], blocked)
		if ci2 < 0:
			continue
		if s.key == "bunker":
			start = ci2
			start_pt = dp[0]
		else:
			targets.append({"cell": ci2, "pt": dp[0], "d": 0.0})
	if start < 0:
		start = _cell_ok(w.world_to_cell(Vector2(0, 6)), blocked)
		start_pt = Vector2(0, 6)
	var net := {}
	path_cells.resize(n)
	path_cells.fill(0)
	routes.clear()
	if start >= 0:
		net[start] = true
		var sp: Vector2 = w.cell_min(start % gm, start / gm) + Vector2(1, 1)
		for t in targets:
			t.d = sp.distance_to(t.pt)
		targets.sort_custom(func(a, b): return a.d < b.d)
		for t in targets:
			var cells := _route(int(t.cell), net, cost, gm)
			if cells.is_empty():
				continue
			var pts := PackedVector2Array()
			pts.append(t.pt)
			for c in cells:
				pts.append(w.cell_min(c % gm, c / gm) + Vector2(1, 1))
				net[c] = true
			routes.append(_smooth(pts))
		routes.append(_smooth(PackedVector2Array([start_pt, w.cell_min(start % gm, start / gm) + Vector2(1, 1)])))
	# hinaus durch die Tore
	for o in outs:
		var p0: Vector2 = o[0]
		var dir: Vector2 = o[1]
		var line := PackedVector2Array([p0 - dir * 2.0, p0 + dir * 6.0, p0 + dir * 12.0 + dir.orthogonal() * 1.0])
		routes.append(line)
	for c in net:
		path_cells[int(c)] = 1
	# Maske malen
	var buf := _static.duplicate()
	for r in routes:
		_stamp_line(buf, r, 1.45, 0, 0.55, 0.12)
	for d in 4:
		var v: Vector2 = w.DIR_VEC[d]
		var side := v.orthogonal()
		_stamp_line(buf, PackedVector2Array([v * 70.0 + side * 3.0, v * 58.0 - side * 1.0, v * 52.0 - side * 2.0, v * 45.0]), 1.7, 0, 0.55, 0.15)
	for b in P.d.buildings:
		var sz := P.size_of(String(b.key), int(b.rot))
		var a: Vector2 = w.cell_min(int(b.x), int(b.y))
		var inset := 0.25 if b.key != "wall" else 0.55
		if String(b.key).begins_with("hind_"):
			continue
		_fill_rect(buf, a + Vector2(inset, inset), a + Vector2(sz.x, sz.y) * D.CELL - Vector2(inset, inset), 3)
	var img := Image.create_from_data(RES, RES, false, Image.FORMAT_RGBA8, buf)
	mask_old = mask_now
	mask_now = ImageTexture.create_from_image(img)
	mask_mix = 0.0 if rebuilds > 1 else 1.0
	_apply_mask()
	_place_lamps(blocked, gm)
	_place_plants(occ, gm)
	last_rebuild_ms = (Time.get_ticks_usec() - t0) / 1000.0


## Türpunkt eines Gebäudes: Leerobjekt "door", sonst Mitte der Vorderkante. Rückgabe [Punkt, Blickrichtung].
func door_point(s: Node3D) -> Array:
	var rot := int(s.b.get("rot", 0)) if s.b is Dictionary else 0
	var th := -rot * PI * 0.5
	var front := Vector2(sin(th), cos(th))
	var dn: Node3D = Models.find(s.model, "door") if s.model != null else null
	if dn != null and dn.is_inside_tree():
		return [Vector2(dn.global_position.x, dn.global_position.z), front]
	var half: float = (s.size.y if rot % 2 == 0 else s.size.x) * D.CELL * 0.5
	return [s.mid + front * half, front]


func _cell_ok(c: Vector2i, blocked: PackedByteArray) -> int:
	var gm := D.GRID_MAX
	if c.x < 0 or c.y < 0 or c.x >= gm or c.y >= gm:
		return -1
	return c.x + c.y * gm if blocked[c.x + c.y * gm] == 0 else -1


func _door_cell(dp: Vector2, front: Vector2, blocked: PackedByteArray) -> int:
	for k in [1.0, 2.5, 4.5]:
		var ci := _cell_ok(w.world_to_cell(dp + front * k), blocked)
		if ci >= 0:
			return ci
	var c0: Vector2i = w.world_to_cell(dp + front)
	for r in range(1, 3):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var ci := _cell_ok(c0 + Vector2i(dx, dy), blocked)
				if ci >= 0:
					return ci
	return -1


## Dijkstra vom Ziel bis zum nächsten Feld des bisherigen Wegenetzes (bisherige Wege sind billig).
func _route(from: int, net: Dictionary, cost: PackedFloat32Array, gm: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if net.has(from):
		out.append(from)
		return out
	var n := gm * gm
	var dist := PackedFloat32Array()
	dist.resize(n)
	dist.fill(1.0e9)
	var prev := PackedInt32Array()
	prev.resize(n)
	prev.fill(-1)
	var hk := PackedFloat32Array()
	var hv := PackedInt32Array()
	dist[from] = 0.0
	_push(hk, hv, 0.0, from)
	var found := -1
	while hv.size() > 0:
		var d := hk[0]
		var i := hv[0]
		_pop(hk, hv)
		if d > dist[i]:
			continue
		if net.has(i):
			found = i
			break
		var x := i % gm
		var y := i / gm
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var xx := x + dx
				var yy := y + dy
				if xx < 0 or yy < 0 or xx >= gm or yy >= gm:
					continue
				var j := xx + yy * gm
				var cj := cost[j]
				if cj < 0.0:
					continue
				var step := 1.0
				if dx != 0 and dy != 0:
					if cost[x + dx + y * gm] < 0.0 or cost[x + (y + dy) * gm] < 0.0:
						continue
					step = 1.42
				var nd := d + step * (0.3 if net.has(j) else cj)
				if nd < dist[j]:
					dist[j] = nd
					prev[j] = i
					_push(hk, hv, nd, j)
	if found < 0:
		return out
	var c := found
	while c >= 0:
		out.append(c)
		c = prev[c]
	out.reverse()           # jetzt vom Ziel (Tür) zum Netz
	return out


static func _push(hk: PackedFloat32Array, hv: PackedInt32Array, k: float, v: int) -> void:
	hk.append(k)
	hv.append(v)
	var i := hk.size() - 1
	while i > 0:
		var p := (i - 1) >> 1
		if hk[p] <= hk[i]:
			break
		var tk := hk[p]
		hk[p] = hk[i]
		hk[i] = tk
		var tv := hv[p]
		hv[p] = hv[i]
		hv[i] = tv
		i = p


static func _pop(hk: PackedFloat32Array, hv: PackedInt32Array) -> void:
	var last := hk.size() - 1
	hk[0] = hk[last]
	hv[0] = hv[last]
	hk.resize(last)
	hv.resize(last)
	var i := 0
	while true:
		var l := i * 2 + 1
		var r := l + 1
		var m := i
		if l < last and hk[l] < hk[m]:
			m = l
		if r < last and hk[r] < hk[m]:
			m = r
		if m == i:
			break
		var tk := hk[m]
		hk[m] = hk[i]
		hk[i] = tk
		var tv := hv[m]
		hv[m] = hv[i]
		hv[i] = tv
		i = m


## Glättet einen Linienzug (Chaikin, zwei Durchgänge, Endpunkte bleiben).
static func _smooth(pts: PackedVector2Array) -> PackedVector2Array:
	var p := pts
	for it in 2:
		if p.size() < 3:
			return p
		var q := PackedVector2Array()
		q.append(p[0])
		for i in p.size() - 1:
			q.append(p[i].lerp(p[i + 1], 0.25))
			q.append(p[i].lerp(p[i + 1], 0.75))
		q.append(p[p.size() - 1])
		p = q
	return p


# ---------------------------------------------------------------- Wiese, Blumen
func _mmi(model: String, mat: Material, xforms: Array, vis_end := 0.0, shadow := false) -> MultiMeshInstance3D:
	if not Models.has_glb(model) or xforms.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Models.glb_mesh(model, "body")
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if vis_end > 0.0:
		mi.visibility_range_end = vis_end
	add_child(mi)
	return mi


func _land_ok(p: Vector2) -> bool:
	return not in_sea(p, -1.0) and absf(p.x) < 70.0 and absf(p.y) < 70.0


func _make_meadow() -> void:
	var q := G.quality()
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var half := float(D.GRID_MAX) * D.CELL * 0.5
	var tuft_mat := MK.mat_wind3(0.55, 0.9, 1.0, 1.0, 1.0)
	var flower_mat := MK.mat_wind3(0.5, 1.2, 1.0, 1.0, 0.0)
	var small_mat := MK.mat_wind3(0.35, 0.7, 1.0, 1.0, 0.0)
	_mats.append_array([tuft_mat, flower_mat, small_mat])
	# (2) Grasbüschel: dichter am Rand, im Baufeld niedrig
	var tf := [[], []]
	var nt: int = N_TUFT[q]
	var i := 0
	var tries := 0
	while i < nt and tries < nt * 3:
		tries += 1
		var inside := rng.randf() < 0.5
		var p: Vector2
		if inside:
			p = Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half))
		else:
			p = Vector2(rng.randf_range(-66, 66), rng.randf_range(-66, 66))
			if maxf(absf(p.x), absf(p.y)) < half:
				continue
		if not _land_ok(p):
			continue
		var s := rng.randf_range(0.75, 1.05) if inside else rng.randf_range(0.9, 1.5)
		tf[i % 2].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.2), s)), Vector3(p.x, 0, p.y)))
		i += 1
	_mmi("p_gtuft_1", tuft_mat, tf[0])
	_mmi("p_gtuft_2", tuft_mat, tf[1])
	# (3) Klee und hohe Halme als Tupfer (Halme eher am Rand)
	var cl: Array = []
	var tg: Array = []
	for k in N_SMALL[q]:
		var p := Vector2(rng.randf_range(-64, 64), rng.randf_range(-64, 64))
		if not _land_ok(p):
			continue
		var edge := maxf(absf(p.x), absf(p.y)) > half - 4.0
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.3)), Vector3(p.x, 0, p.y))
		if edge and rng.randf() < 0.7:
			tg.append(xf)
		else:
			cl.append(xf)
	_mmi("p_clover", small_mat, cl)
	_mmi("p_tallgrass", small_mat, tg)
	# Blumen in Gruppen von 5 bis 15
	var fl := [[], [], [], [], [], []]
	var nf: int = N_FLOWER[q]
	var made := 0
	while made < nf:
		var c := Vector2(rng.randf_range(-62, 62), rng.randf_range(-62, 62))
		if rng.randf() < 0.45:
			c *= 0.55                                  # mehr Blumen zwischen den Gebäuden
		if not _land_ok(c):
			continue
		var kind := rng.randi_range(0, 5)
		if kind == 5 and rng.randf() < 0.6:
			kind = rng.randi_range(0, 4)
		var cnt := rng.randi_range(5, 15)
		flower_spots.append(c)
		for k in cnt:
			var a := rng.randf() * TAU
			var p := c + Vector2(cos(a), sin(a)) * rng.randf_range(0.2, 1.7)
			var s := rng.randf_range(0.8, 1.2)
			fl[kind].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(p.x, 0, p.y)))
			made += 1
	for k in 6:
		_mmi("p_flower_%d" % (k + 1), flower_mat, fl[k])


# ---------------------------------------------------------------- Pflanzen im Baufeld
func _make_plant_meshes() -> void:
	var all := PLANT_TREES + PLANT_SMALL
	for m in all:
		if _mm.has(m) or not Models.has_glb(m):
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = Models.glb_mesh(m, "body")
		mm.instance_count = 0
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		var tree: bool = m.begins_with("p_tree")
		var wmat := MK.mat_wind3(0.012 if tree else 0.08, 0.0, 0.0, 1.0, 0.0)
		_mats.append(wmat)
		mi.material_override = wmat
		mi.custom_aabb = AABB(Vector3(-50, -1, -50), Vector3(100, 12, 100))
		if not tree or G.quality() == 0:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_mm[m] = mm


func _place_plants(occ: Dictionary, gm: int) -> void:
	var o := P.grid_origin()
	var ng := P.grid_size()
	# frei: kein Gebäude im Umkreis von 2 Feldern, kein Weg daneben
	var valid := {}
	for y in range(o, o + ng):
		for x in range(o, o + ng):
			var ok := true
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					if occ.has((x + dx) + (y + dy) * 64):
						ok = false
						break
				if not ok:
					break
			if not ok:
				continue
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var xx := x + dx
					var yy := y + dy
					if xx >= 0 and yy >= 0 and xx < gm and yy < gm and path_cells[xx + yy * gm] == 1:
						ok = false
			if ok:
				valid[Vector2i(x, y)] = true
	var want_trees := int(valid.size() / 30)
	var want_small := want_trees * 2 + 2
	var used := {}
	var keep: Array = []
	var puff: bool = w.time > 1.0
	for pl in _plants:
		if valid.has(pl.c) and not used.has(pl.c):
			used[pl.c] = true
			keep.append(pl)
		elif puff and G.fx != null:
			var wp: Vector2 = w.cell_min(pl.c.x, pl.c.y) + Vector2(1, 1) + pl.off
			G.fx.puff(Vector3(wp.x, 0.8, wp.y), Color(0.55, 0.8, 0.35), 12, 1.2)
			Sfx.play_at("plant_puff", Vector3(wp.x, 0, wp.y), -12.0, 1.0, 0.15)
	var trees: Array = keep.filter(func(p): return p.tree)
	var small: Array = keep.filter(func(p): return not p.tree)
	while trees.size() > want_trees:
		used.erase(trees.pop_back().c)
	while small.size() > want_small:
		used.erase(small.pop_back().c)
	var cand: Array = valid.keys()
	cand.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = 991 + rebuilds
	for k in range(cand.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var t = cand[k]
		cand[k] = cand[j]
		cand[j] = t
	var ci := 0
	for kind in 2:
		var lst: Array = trees if kind == 0 else small
		var want := want_trees if kind == 0 else want_small
		while lst.size() < want and ci < cand.size():
			var c: Vector2i = cand[ci]
			ci += 1
			if used.has(c):
				continue
			if kind == 0:
				var near := false
				for t in trees:
					if absi(t.c.x - c.x) < 3 and absi(t.c.y - c.y) < 3:
						near = true
						break
				if near:
					continue
			used[c] = true
			var model: String = PLANT_TREES[rng.randi() % PLANT_TREES.size()] if kind == 0 else PLANT_SMALL[rng.randi() % PLANT_SMALL.size()]
			lst.append({"m": model, "c": c, "yaw": rng.randf() * TAU, "s": rng.randf_range(0.75, 1.05) if kind == 0 else rng.randf_range(0.8, 1.2),
				"off": Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5)), "tree": kind == 0})
	_plants = trees + small
	if _ring_size != ng:
		_make_ring(o, ng, gm)
	perch_spots.clear()
	var per := {}
	for pl in _plants + _ring:
		if not per.has(pl.m):
			per[pl.m] = []
		var wp: Vector2 = w.cell_min(pl.c.x, pl.c.y) + Vector2(1, 1) + pl.off
		var sc: float = pl.s * (0.55 if pl.m == "p_mushroom_1" else 1.0)
		pl["k"] = per[pl.m].size()                       # Paket Welt: Platz im MultiMesh (gefällte Bäume)
		if felled.has(_tree_key(pl)):
			sc = 0.0
		per[pl.m].append(Transform3D(Basis(Vector3.UP, pl.yaw).scaled(Vector3.ONE * sc), Vector3(wp.x, 0, wp.y)))
		if pl.tree:
			perch_spots.append(Vector3(wp.x, 3.6 * pl.s, wp.y))
	for m in _mm:
		var mm: MultiMesh = _mm[m]
		var list: Array = per.get(m, [])
		mm.instance_count = list.size()
		for k in list.size():
			mm.set_instance_transform(k, list[k])


## Waldsaum zwischen Baufeld und Wald: dichte Bäume und Büsche auf dem Teil des größten Rasters, der noch
## nicht bebaubar ist (wächst der Bunker, rückt der Saum nach außen). Zufahrten und Lichtungen bleiben frei.
func _make_ring(o: int, ng: int, gm: int) -> void:
	_ring_size = ng
	_ring.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var clear := FastNoiseLite.new()
	clear.seed = 9
	clear.frequency = 0.09
	for y in gm:
		for x in gm:
			var d := maxi(maxi(o - x, x - (o + ng - 1)), maxi(o - y, y - (o + ng - 1)))
			if d < 3:
				continue
			var c: Vector2 = w.cell_min(x, y) + Vector2(1, 1)
			if minf(absf(c.x), absf(c.y)) < 11.0 or in_sea(c, -4.0) or coast_s(c) > BEACH_S - 1.5:
				continue
			var r := rng.randf()
			if clear.get_noise_2d(c.x, c.y) > 0.3:
				if r < 0.25:
					_ring.append({"m": PLANT_SMALL[rng.randi() % 3], "c": Vector2i(x, y), "yaw": rng.randf() * TAU, "s": rng.randf_range(0.8, 1.3),
						"off": Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5)), "tree": false})
				continue
			if r < 0.42:
				var m: String = PLANT_TREES[rng.randi() % 3] if rng.randf() < 0.75 else PLANT_TREES[3 + rng.randi() % 2]
				_ring.append({"m": m, "c": Vector2i(x, y), "yaw": rng.randf() * TAU, "s": rng.randf_range(0.85, 1.35),
					"off": Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6)), "tree": true})
			elif r < 0.6:
				_ring.append({"m": PLANT_SMALL[rng.randi() % PLANT_SMALL.size()], "c": Vector2i(x, y), "yaw": rng.randf() * TAU, "s": rng.randf_range(0.9, 1.4),
					"off": Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5)), "tree": false})


func plant_count() -> int:
	return _plants.size()


func tree_count() -> int:
	return _plants.filter(func(p): return p.tree).size()


## Steht eine Pflanze auf einem bebauten Feld? (Test)
func plants_on_buildings() -> int:
	var occ := P.occupancy()
	var n := 0
	for pl in _plants:
		if occ.has(pl.c.x + pl.c.y * 64):
			n += 1
	return n


# ---------------------------------------------------------------- Laternen und Wegweiser
func _make_lamp_meshes() -> void:
	for k in 3:
		var model := "p_path_lamp" if k < 2 else "p_signpost"
		if not Models.has_glb(model):
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = Models.glb_mesh(model, "lamp_glow" if k == 1 else "body")
		mm.instance_count = 0
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = lamp_mat if k == 1 else MK.mat_lin()
		mi.custom_aabb = AABB(Vector3(-60, -1, -60), Vector3(120, 8, 120))
		if k == 1:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		match k:
			0:
				_lamp_mm = mm
			1:
				_lamp_glow_mm = mm
			2:
				_sign_mm = mm


func _place_lamps(blocked: PackedByteArray, gm: int) -> void:
	lamp_spots.clear()
	var lamps: Array = []
	var glows: Array = []
	var glow_off := Vector3(0, 2.62, 0)
	for r: PackedVector2Array in routes:
		var acc := 5.0
		for i in r.size() - 1:
			var a := r[i]
			var b := r[i + 1]
			var ln := a.distance_to(b)
			if ln < 0.01:
				continue
			var t := 0.0
			while t < ln:
				var step := minf(ln - t, 11.0 - acc)
				t += step
				acc += step
				if acc >= 11.0:
					acc = 0.0
					var p := a.lerp(b, t / ln)
					var side := (b - a).normalized().orthogonal() * 1.5
					var q := p + side
					var c: Vector2i = w.world_to_cell(q)
					if c.x < 0 or c.y < 0 or c.x >= gm or c.y >= gm or blocked[c.x + c.y * gm] == 1 or path_cells[c.x + c.y * gm] == 1:
						q = p - side
						c = w.world_to_cell(q)
						if c.x < 0 or c.y < 0 or c.x >= gm or c.y >= gm or blocked[c.x + c.y * gm] == 1:
							continue
					var close := false
					for o in lamp_spots:
						if o.distance_to(q) < 7.0:
							close = true
							break
					if close:
						continue
					lamp_spots.append(q)
					var xf := Transform3D(Basis.IDENTITY, Vector3(q.x, 0, q.y))
					lamps.append(xf)
					glows.append(xf.translated(glow_off))
	# Wegweiser an Kreuzungen (Wegfeld mit mindestens drei Weg-Nachbarn)
	var signs: Array = []
	var spots: Array = []
	for i in gm * gm:
		if path_cells[i] != 1:
			continue
		var x := i % gm
		var y := i / gm
		var nb := 0
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var xx: int = x + d.x
			var yy: int = y + d.y
			if xx >= 0 and yy >= 0 and xx < gm and yy < gm and path_cells[xx + yy * gm] == 1:
				nb += 1
		if nb < 3:
			continue
		var p: Vector2 = w.cell_min(x, y) + Vector2(1, 1)
		var ok := true
		for s in spots:
			if s.distance_to(p) < 12.0:
				ok = false
				break
		if not ok:
			continue
		# Platz neben der Kreuzung, der weder Weg noch Gebäude ist
		for d in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var xx: int = x + d.x
			var yy: int = y + d.y
			if xx >= 0 and yy >= 0 and xx < gm and yy < gm and path_cells[xx + yy * gm] == 0 and blocked[xx + yy * gm] == 0:
				var q: Vector2 = p + Vector2(d.x, d.y) * 1.2
				spots.append(p)
				signs.append(Transform3D(Basis(Vector3.UP, atan2(p.x - q.x, p.y - q.y)), Vector3(q.x, 0, q.y)))
				break
		if signs.size() >= 6:
			break
	for k in 3:
		var mm: MultiMesh = [_lamp_mm, _lamp_glow_mm, _sign_mm][k]
		if mm == null:
			continue
		var list: Array = [lamps, glows, signs][k]
		mm.instance_count = list.size()
		for j in list.size():
			mm.set_instance_transform(j, list[j])


func sign_count() -> int:
	return _sign_mm.instance_count if _sign_mm != null else 0


# ---------------------------------------------------------------- Küste und Bach
## Meer in der Südwest-Ecke (gesperrt, nur Luftkissenboot), Strandfelsen, Holzsteg, schaukelndes Boot;
## der Bach im Osten (gesperrt bis auf die Ost-Zufahrt mit der Holzbrücke – dort waten Gegner auch durch die Furt).
func make_coast(rng: RandomNumberGenerator) -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(170, 64)
	var sea := MeshInstance3D.new()
	sea.mesh = pm
	var sc := COAST_S + 30.0
	sea.position = Vector3(-sc * DIAG, 0.06, sc * DIAG)
	sea.rotation.y = -PI * 0.25
	sea_mat = ShaderMaterial.new()
	sea_mat.shader = load("res://shaders/sea.gdshader")
	sea_mat.set_shader_parameter("coast_s", COAST_S)
	if w.ground_mat != null:
		sea_mat.set_shader_parameter("noise_tex", w.ground_mat.get_shader_parameter("noise_tex"))
	sea.material_override = sea_mat
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)
	var f = w.field
	for z in f.h:
		for x in f.w:
			var c: Vector2 = f.center(x + z * f.w)
			if in_sea(c, -0.6):
				f.block_rect(c - Vector2(0.9, 0.9), c + Vector2(0.9, 0.9), true)
			elif in_brook(c, 1.7) and absf(c.y - BRIDGE.y) > 2.6:      # nur über die Brücke (5 m breit), nicht durch die Furt
				f.block_rect(c - Vector2(0.9, 0.9), c + Vector2(0.9, 0.9), true)
	# Steg und Boot
	var sea_dir := Vector2(-DIAG, DIAG)
	var yaw := atan2(sea_dir.x, sea_dir.y)
	jetty = w.place_model("p_jetty", Vector3(JETTY_AT.x, 0, JETTY_AT.y), yaw) if Models.has_glb("p_jetty") else null
	var end := JETTY_AT + sea_dir * 10.0 + sea_dir.orthogonal() * 3.1
	boat = w.place_model("p_boat", Vector3(end.x, 0, end.y), yaw + 0.12) if Models.has_glb("p_boat") else null
	# Strandfelsen in Gruppen entlang des Ufers
	for g in 9:
		var t := rng.randf_range(-70.0, 70.0)
		var s := COAST_S + rng.randf_range(-4.5, 1.0)
		var c2 := Vector2(-s * DIAG, s * DIAG) + Vector2(DIAG, DIAG) * t
		if absf(c2.x) > 68.0 or absf(c2.y) > 68.0 or c2.distance_to(JETTY_AT) < 6.0 or coast_s(c2) < BEACH_S:
			continue
		for k in rng.randi_range(2, 4):
			var q := c2 + Vector2(rng.randf_range(-2.2, 2.2), rng.randf_range(-2.2, 2.2))
			w.scatter("p_beach_rock_%d" % rng.randi_range(1, 2), Vector3(q.x, -0.1, q.y), rng.randf() * TAU, rng.randf_range(0.7, 1.5))
			if not in_sea(q):
				f.block_circle(q, 1.0)
	# Holzbrücke über den Bach an der Ost-Zufahrt
	if Models.has_glb("p_bridge"):
		w.place_model("p_bridge", Vector3(BRIDGE.x, 0.05, BRIDGE.y), PI * 0.5, 1.0)


## Wald, Felsgruppen und Lichtungen außerhalb des Baufelds (Zufahrten, Küste und Bach bleiben frei).
func make_forest(rng: RandomNumberGenerator) -> void:
	var q := G.quality()
	var n: int = [520, 760, 980][q]
	var clear := FastNoiseLite.new()
	clear.seed = 77
	clear.frequency = 0.05
	var f = w.field
	for i in n:
		var p := Vector2(rng.randf_range(-100, 100), rng.randf_range(-100, 100))
		var edge := maxf(absf(p.x), absf(p.y))
		if edge < 47.5:
			continue
		if minf(absf(p.x), absf(p.y)) < 11.0:
			continue
		if in_sea(p, -3.0) or coast_s(p) > BEACH_S - 2.0 or in_brook(p, 3.2):
			continue
		# Lichtungen: hier nur Wiese
		if clear.get_noise_2d(p.x, p.y) > 0.35 and edge < 75.0:
			continue
		var p3 := Vector3(p.x, 0, p.y)
		var k := rng.randf()
		if k < 0.62:
			if rng.randf() < 0.18:
				w.scatter_var("p_tree_leaf", 2, p3, rng, 0.9, 1.3)
			else:
				w.scatter_var("p_tree_pine", 3, p3, rng, 0.9, 1.45)
			if edge < 66.0:
				f.block_circle(p, 1.0)
		elif k < 0.7:
			# Felsgruppe
			for j in rng.randi_range(2, 4):
				var r := p + Vector2(rng.randf_range(-1.8, 1.8), rng.randf_range(-1.8, 1.8))
				w.scatter_var("p_rock", 3, Vector3(r.x, 0, r.y), rng, 0.6, 1.6)
				if edge < 66.0:
					f.block_circle(r, 1.2)
		elif k < 0.84:
			w.scatter_var("p_shrub", 3, p3, rng, 0.9, 1.5)
		elif k < 0.92:
			w.scatter("p_fern", p3, rng.randf() * TAU, rng.randf_range(1.0, 1.6))
		elif k < 0.96:
			w.scatter("p_stump_1" if rng.randf() < 0.5 else "p_log_1", p3, rng.randf() * TAU)
		else:
			w.scatter("p_mushroom_1", p3, rng.randf() * TAU)
	# Büsche und Farn entlang des Bachs
	for i in BROOK.size() - 1:
		for k in 3:
			var b0: Vector2 = BROOK[i]
			var b1: Vector2 = BROOK[i + 1]
			var c := b0.lerp(b1, rng.randf())
			var side := (b1 - b0).normalized().orthogonal() * (2.6 if rng.randf() < 0.5 else -2.6)
			var p := c + side + Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6))
			if absf(p.y - BRIDGE.y) < 9.0 and absf(p.x - BRIDGE.x) < 9.0:
				continue
			if maxf(absf(p.x), absf(p.y)) < 47.0:
				continue
			w.scatter("p_fern" if k == 0 else "p_shrub_%d" % rng.randi_range(1, 3), Vector3(p.x, 0, p.y), rng.randf() * TAU, rng.randf_range(0.8, 1.2))


# ---------------------------------------------------------------- Bäume fällen (Paket Welt)
## Holzfäller fällen echte Bäume der Basis (Pflanzen im Baufeld und Waldsaum); nach einer Weile wächst der Baum nach.
const _DW = preload("res://src/data_welt.gd")


func _tree_key(pl: Dictionary) -> String:
	return "%d:%d:%s" % [pl.c.x, pl.c.y, pl.m]


func tree_pos(pl: Dictionary) -> Vector2:
	return w.cell_min(pl.c.x, pl.c.y) + Vector2(1, 1) + pl.off


## Stehende Bäume im Umkreis r um c (nächster zuerst); skip = Schlüssel, die schon jemand fällt.
func trees_near(c: Vector2, r: float, skip: Dictionary = {}) -> Array:
	var out: Array = []
	for pl in _plants + _ring:
		if not pl.tree or felled.has(_tree_key(pl)) or skip.has(_tree_key(pl)):
			continue
		var d := tree_pos(pl).distance_to(c)
		if d < r:
			out.append([d, pl])
	out.sort_custom(func(a, b): return a[0] < b[0])
	return out.map(func(x): return x[1])


## Baum fällt (vom Holzfäller weg), Stumpf bleibt stehen.
func fell_tree(pl: Dictionary, from: Vector2) -> void:
	var key := _tree_key(pl)
	if felled.has(key) or not _mm.has(pl.m):
		return
	var p := tree_pos(pl)
	var mm: MultiMesh = _mm[pl.m]
	var k := int(pl.get("k", -1))
	if k >= 0 and k < mm.instance_count:
		var tr := mm.get_instance_transform(k)
		mm.set_instance_transform(k, Transform3D(Basis().scaled(Vector3.ZERO), tr.origin))
	var stump: Node3D = null
	if Models.has_glb("n_stump"):
		stump = Models.glb("n_stump")
		stump.position = Vector3(p.x, 0, p.y)
		stump.scale = Vector3.ONE * float(pl.s) * 0.8
		add_child(stump)
	felled[key] = {"t": w.time, "stump": stump, "pl": pl}
	# fallender Stamm: Modell kippt in 1,1 s um, versinkt dann
	if Models.has_glb(pl.m):
		var n := Models.glb(pl.m)
		n.position = Vector3(p.x, 0, p.y)
		n.rotation.y = float(pl.yaw)
		n.scale = Vector3.ONE * float(pl.s)
		add_child(n)
		var dir := (p - from).normalized() if p.distance_to(from) > 0.1 else Vector2.RIGHT
		var axis := Vector3(dir.y, 0, -dir.x)
		var tw := n.create_tween()
		tw.tween_method(func(a: float): n.basis = Basis(axis, a * a * PI * 0.47).rotated(Vector3.UP, 0.0) * Basis(Vector3.UP, float(pl.yaw)).scaled(Vector3.ONE * float(pl.s)), 0.0, 1.0, 1.1)
		tw.tween_interval(1.4)
		tw.tween_property(n, "position:y", -2.5, 1.2)
		tw.tween_callback(n.queue_free)
	Sfx.play_at("tree_fall", Vector3(p.x, 0, p.y), -6.0, 1.0, 0.2)
	if G.fx != null:
		G.fx.puff(Vector3(p.x, 1.2, p.y), Color(0.5, 0.75, 0.3), 14, 1.4)


func _regrow() -> void:
	for key in felled.keys():
		var f: Dictionary = felled[key]
		if w.time - float(f.t) < _DW.NPC_TREE_REGROW:
			continue
		var pl: Dictionary = f.pl
		felled.erase(key)
		if f.stump != null and is_instance_valid(f.stump):
			f.stump.queue_free()
		if _mm.has(pl.m):
			var mm: MultiMesh = _mm[pl.m]
			var k := int(pl.get("k", -1))
			if k >= 0 and k < mm.instance_count:
				var p := tree_pos(pl)
				mm.set_instance_transform(k, Transform3D(Basis(Vector3.UP, float(pl.yaw)).scaled(Vector3.ONE * float(pl.s)), Vector3(p.x, 0, p.y)))
				if G.fx != null:
					G.fx.puff(Vector3(p.x, 0.8, p.y), Color(0.55, 0.85, 0.35), 10, 1.2)
