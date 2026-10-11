extends RefCounted
## Richtungsfeld für die Horde. Die Karte ist ein Raster; vom Ziel (Bunker) aus wird für
## jede Zelle der günstigste Weg berechnet. Gegner lesen nur die Richtung ihrer Zelle.
##
## Gebäude und Mauern sind nicht unpassierbar, sondern "teuer": Gibt es einen offenen Weg,
## nimmt die Horde ihn. Ist alles zugebaut, läuft sie zum billigsten Hindernis und greift es an.
## So kann man die Flut nie vollständig aussperren.

const BIG := 1.0e9

var cs := 1.0                         # Zellgröße in Metern
var w := 0
var h := 0
var ox := 0.0
var oz := 0.0
var goal := Vector2.ZERO
var base := PackedFloat32Array()      # Grundkosten je Zelle
var solid := PackedByteArray()        # 1 = Fels, Wasser, Kartenrand
var water := PackedByteArray()        # 1 = Wasser (nur Luftkissenboot)
var dist := PackedFloat32Array()
var dirs := PackedVector2Array()
var cells := {}                       # Zellindex -> Objekt mit .alive, .mid, .cost, hurt()
var dirty := true
var rebuilds := 0
var has_goal := false


func _init(origin: Vector2, width: int, height: int, cell_size: float) -> void:
	cs = cell_size
	w = width
	h = height
	ox = origin.x
	oz = origin.y
	var n := w * h
	base.resize(n)
	solid.resize(n)
	water.resize(n)
	dist.resize(n)
	dirs.resize(n)
	for i in n:
		base[i] = 1.0


func set_goal(p: Vector2) -> void:
	goal = p
	has_goal = true
	dirty = true


func idx(p: Vector2) -> int:
	var x := int(floor((p.x - ox) / cs))
	var z := int(floor((p.y - oz) / cs))
	if x < 0 or z < 0 or x >= w or z >= h:
		return -1
	return x + z * w


func center(i: int) -> Vector2:
	return Vector2(ox + ((i % w) + 0.5) * cs, oz + (int(i / w) + 0.5) * cs)


func in_bounds(p: Vector2, margin := 0.0) -> bool:
	return p.x > ox + margin and p.y > oz + margin and p.x < ox + w * cs - margin and p.y < oz + h * cs - margin


## Wie block_circle, gibt aber nur die Felder zurück, die vorher frei waren (zum späteren Freigeben).
func block_circle_tracked(c: Vector2, r: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var x0 := int(floor((c.x - r - ox) / cs))
	var x1 := int(floor((c.x + r - ox) / cs))
	var z0 := int(floor((c.y - r - oz) / cs))
	var z1 := int(floor((c.y + r - oz) / cs))
	for z in range(maxi(z0, 0), mini(z1, h - 1) + 1):
		for x in range(maxi(x0, 0), mini(x1, w - 1) + 1):
			var p := Vector2(ox + (x + 0.5) * cs, oz + (z + 0.5) * cs)
			if p.distance_to(c) <= r and solid[x + z * w] == 0:
				solid[x + z * w] = 1
				out.append(x + z * w)
	dirty = true
	return out


## Gibt Felder wieder frei (abgebaute Rohstoffquelle).
func release_cells(cells: PackedInt32Array) -> void:
	for i in cells:
		if i >= 0 and i < solid.size():
			solid[i] = 0
	dirty = true


func block_circle(c: Vector2, r: float, as_water := false) -> void:
	var x0 := int(floor((c.x - r - ox) / cs))
	var x1 := int(floor((c.x + r - ox) / cs))
	var z0 := int(floor((c.y - r - oz) / cs))
	var z1 := int(floor((c.y + r - oz) / cs))
	for z in range(maxi(z0, 0), mini(z1, h - 1) + 1):
		for x in range(maxi(x0, 0), mini(x1, w - 1) + 1):
			var p := Vector2(ox + (x + 0.5) * cs, oz + (z + 0.5) * cs)
			if p.distance_to(c) <= r:
				solid[x + z * w] = 1
				if as_water:
					water[x + z * w] = 1
	dirty = true


func block_rect(a: Vector2, b: Vector2, as_water := false) -> void:
	var x0 := maxi(int(floor((a.x - ox) / cs)), 0)
	var x1 := mini(int(floor((b.x - ox) / cs)), w - 1)
	var z0 := maxi(int(floor((a.y - oz) / cs)), 0)
	var z1 := mini(int(floor((b.y - oz) / cs)), h - 1)
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			solid[x + z * w] = 1
			if as_water:
				water[x + z * w] = 1
	dirty = true


func clear_rect(a: Vector2, b: Vector2) -> void:
	var x0 := maxi(int(floor((a.x - ox) / cs)), 0)
	var x1 := mini(int(floor((b.x - ox) / cs)), w - 1)
	var z0 := maxi(int(floor((a.y - oz) / cs)), 0)
	var z1 := mini(int(floor((b.y - oz) / cs)), h - 1)
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			solid[x + z * w] = 0
			water[x + z * w] = 0
	dirty = true


func is_solid(p: Vector2) -> bool:
	var i := idx(p)
	return i < 0 or solid[i] == 1


## Für Fahrzeuge, die über Wasser fahren können.
func is_solid_for(p: Vector2, hover: bool) -> bool:
	var i := idx(p)
	if i < 0:
		return true
	if solid[i] == 0:
		return false
	return not (hover and water[i] == 1)


## Trägt ein angreifbares Objekt (Gebäude, Mauer) in die Zellen eines Rechtecks ein.
func add_structure(obj, a: Vector2, b: Vector2) -> void:
	var x0 := maxi(int(floor((a.x + 0.01 - ox) / cs)), 0)
	var x1 := mini(int(floor((b.x - 0.01 - ox) / cs)), w - 1)
	var z0 := maxi(int(floor((a.y + 0.01 - oz) / cs)), 0)
	var z1 := mini(int(floor((b.y - 0.01 - oz) / cs)), h - 1)
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			cells[x + z * w] = obj
	dirty = true


func clear_structures() -> void:
	cells.clear()
	dirty = true


## Lebendes Objekt an dieser Position oder null.
func structure_at(p: Vector2):
	var i := idx(p)
	if i < 0:
		return null
	var s = cells.get(i)
	if s != null and s.alive:
		return s
	return null


## Blockiert diese Position die Spielfigur? (Gebäude ja, Mauern nein – darüber springt sie.)
func blocks_player(p: Vector2, hover := false) -> bool:
	var i := idx(p)
	if i < 0:
		return true
	if solid[i] == 1 and not (hover and water[i] == 1):
		return true
	var s = cells.get(i)
	return s != null and s.alive and s.blocks_player


func dir_at(p: Vector2) -> Vector2:
	var i := idx(p)
	if i < 0 or not has_goal:
		return (goal - p).normalized()
	return dirs[i]


func update_if_dirty() -> void:
	if dirty and has_goal:
		rebuild()
	dirty = false


func rebuild() -> void:
	dirty = false
	rebuilds += 1
	var n := w * h
	for i in n:
		dist[i] = BIG
	var cost := PackedFloat32Array()
	cost.resize(n)
	for i in n:
		cost[i] = BIG if solid[i] == 1 else base[i]
	for i in cells:
		var s = cells[i]
		if s.alive and solid[i] == 0:
			cost[i] = s.cost
	var hc := PackedFloat32Array()
	var hi := PackedInt32Array()
	var gi := idx(goal)
	if gi < 0:
		return
	dist[gi] = 0.0
	hc.append(0.0)
	hi.append(gi)
	var nx := [1, -1, 0, 0, 1, 1, -1, -1]
	var nz := [0, 0, 1, -1, 1, -1, 1, -1]
	while hc.size() > 0:
		var c0 := hc[0]
		var i0 := hi[0]
		var last := hc.size() - 1
		hc[0] = hc[last]
		hi[0] = hi[last]
		hc.resize(last)
		hi.resize(last)
		var k := 0
		while true:
			var l := k * 2 + 1
			if l >= last:
				break
			var r := l + 1
			var m := l
			if r < last and hc[r] < hc[l]:
				m = r
			if hc[m] >= hc[k]:
				break
			var tc := hc[k]
			hc[k] = hc[m]
			hc[m] = tc
			var ti := hi[k]
			hi[k] = hi[m]
			hi[m] = ti
			k = m
		if c0 > dist[i0] + 0.0005:
			continue
		var cx := i0 % w
		var cz := int(i0 / w)
		for j in 8:
			var x: int = cx + nx[j]
			var z: int = cz + nz[j]
			if x < 0 or z < 0 or x >= w or z >= h:
				continue
			var ni := x + z * w
			var cc := cost[ni]
			if cc >= BIG:
				continue
			var step := 1.0
			if j >= 4:
				# nicht diagonal um Ecken von Hindernissen schneiden
				if cost[cx + nx[j] + cz * w] >= 20.0 or cost[cx + (cz + nz[j]) * w] >= 20.0:
					continue
				step = 1.4142
			var nd := c0 + cc * step
			if nd < dist[ni] - 0.001:
				dist[ni] = nd
				hc.append(nd)
				hi.append(ni)
				var q := hc.size() - 1
				while q > 0:
					var par := (q - 1) >> 1
					if hc[par] <= hc[q]:
						break
					var tc2 := hc[q]
					hc[q] = hc[par]
					hc[par] = tc2
					var ti2 := hi[q]
					hi[q] = hi[par]
					hi[par] = ti2
					q = par
	for z in h:
		for x in w:
			var i := x + z * w
			var here := Vector2(ox + (x + 0.5) * cs, oz + (z + 0.5) * cs)
			if dist[i] >= BIG:
				dirs[i] = (goal - here).normalized()
				continue
			var best := dist[i]
			var bd := Vector2.ZERO
			for j in 8:
				var x2: int = x + nx[j]
				var z2: int = z + nz[j]
				if x2 < 0 or z2 < 0 or x2 >= w or z2 >= h:
					continue
				if j >= 4 and (cost[x2 + z * w] >= 20.0 or cost[x + z2 * w] >= 20.0):
					continue
				var dd := dist[x2 + z2 * w]
				if dd < best:
					best = dd
					bd = Vector2(nx[j], nz[j])
			dirs[i] = bd.normalized() if bd != Vector2.ZERO else (goal - here).normalized()
