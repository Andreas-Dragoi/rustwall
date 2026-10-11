extends RefCounted
## Wegfindung der Bewohner (Paket 2): A*-Suche auf halben Rasterfeldern (1 m) über der Hauptbasis.
## Gesperrt ist, was auch den Helden sperrt (field.blocks_player: Gebäude, Mauern, Kartenrand, Bäume am Rand);
## Tore sperren den Helden nicht und sind deshalb begehbar. Bietet die Welt path_cost(p) an (Paket 5: Wege),
## wird das als Gewicht je Feld benutzt – Bewohner nehmen dann lieber die Pfade.
## Die eigentliche Suche läuft in Godots AStarGrid2D (schnell, ohne Ruckeln); hier werden die Wege geglättet
## (überflüssige Ecken entfernt) und zwischengespeichert, bis sich die Basis ändert (dirty = true).
## Je Bild darf höchstens eine neue Suche laufen (can_search / Zeitscheiben); Treffer aus dem Speicher zählen nicht.

const RES := 1.0                 # Kantenlänge eines Suchfelds (halbes Rasterfeld)

var field                        # Field der Welt (blocks_player)
var world                        # base_world (optional path_cost)
var astar := AStarGrid2D.new()
var origin := Vector2.ZERO       # Weltposition der Ecke von Feld (0, 0)
var n := 0                       # Felder je Seite
var dirty := true
var version := 0                 # zählt jeden Neuaufbau (Bewohner prüfen damit ihren Standort)
var searches := 0                # Zahl der echten Suchen (für Tests)
var _cache := {}
var _frame := -1


func _init(f, w, half: float) -> void:
	field = f
	world = w
	set_area(half)


## Suchgebiet: Quadrat mit halber Kantenlänge half um die Mitte (bleibt innerhalb des Richtungsfelds).
func set_area(half: float) -> void:
	half = clampf(half, 8.0, 64.0)
	var nn := int(ceil(half * 2.0 / RES))
	if nn == n:
		return
	n = nn
	origin = Vector2(-half, -half)
	dirty = true


func rebuild() -> void:
	dirty = false
	version += 1
	_cache.clear()
	astar.region = Rect2i(0, 0, n, n)
	astar.cell_size = Vector2(RES, RES)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	var cost: bool = world != null and world.has_method("path_cost")
	for y in n:
		for x in n:
			var p := cell_center(Vector2i(x, y))
			if field.blocks_player(p):
				astar.set_point_solid(Vector2i(x, y), true)
			elif cost:
				astar.set_point_weight_scale(Vector2i(x, y), maxf(0.1, float(world.path_cost(p))))


func ensure() -> void:
	if dirty:
		rebuild()


func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor((p.x - origin.x) / RES)), int(floor((p.y - origin.y) / RES)))


func cell_center(c: Vector2i) -> Vector2:
	return origin + (Vector2(c) + Vector2(0.5, 0.5)) * RES


func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < n and c.y < n


## Gesperrt für Bewohner? (außerhalb des Suchgebiets: ja)
func blocked(p: Vector2) -> bool:
	var c := cell_of(p)
	if not inside(c):
		return true
	ensure()
	return astar.is_point_solid(c)


## Nächster freier Punkt (Feldmitte) zu p; sucht in Ringen bis max_r Felder weit.
func free_near(p: Vector2, max_r := 12) -> Vector2:
	ensure()
	var c := cell_of(p)
	if inside(c) and not astar.is_point_solid(c):
		return p
	var best := Vector2.INF
	var bd := 1.0e9
	for r in range(1, max_r + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var q := c + Vector2i(dx, dy)
				if not inside(q) or astar.is_point_solid(q):
					continue
				var w := cell_center(q)
				var d := w.distance_squared_to(p)
				if d < bd:
					bd = d
					best = w
		if bd < 1.0e8:
			return best
	return p


func can_search() -> bool:
	return Engine.get_physics_frames() != _frame


## Weg von a nach b als Liste von Wegpunkten (ohne a). Leer, wenn es keinen Weg gibt.
## force = true sucht auch dann, wenn in diesem Bild schon gesucht wurde (nur für Tests).
func find(a: Vector2, b: Vector2, force := false) -> PackedVector2Array:
	ensure()
	var fa := free_near(a, 6)
	var fb := free_near(b, 12)
	var ca := cell_of(fa)
	var cb := cell_of(fb)
	var key := Vector4i(ca.x, ca.y, cb.x, cb.y)
	var out := PackedVector2Array()
	if _cache.has(key):
		out = _cache[key]
	else:
		if not force and not can_search():
			return PackedVector2Array([Vector2.INF])        # Zeichen: später erneut fragen
		_frame = Engine.get_physics_frames()
		searches += 1
		if not inside(ca) or not inside(cb):
			return out
		var ids := astar.get_id_path(ca, cb, true)
		if ids.is_empty():
			_cache[key] = out
			return out
		var pts := PackedVector2Array()
		for id in ids:
			pts.append(cell_center(id))
		out = _smooth(pts)
		if _cache.size() > 400:
			_cache.clear()
		_cache[key] = out
	# Anfangs- und Endpunkt genau setzen (innerhalb der freien Felder)
	var res := out.duplicate()
	if res.size() > 0:
		res.remove_at(0)
	if not blocked(fb):
		if res.size() > 0:
			res[res.size() - 1] = fb
		else:
			res.append(fb)
	if fa != a and not res.is_empty():
		res.insert(0, fa)
	return res


## Überflüssige Ecken entfernen: von jedem Punkt aus der fernste noch frei sichtbare.
func _smooth(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() <= 2:
		return pts
	var out := PackedVector2Array([pts[0]])
	var i := 0
	while i < pts.size() - 1:
		var j := pts.size() - 1
		while j > i + 1 and not clear_line(pts[i], pts[j]):
			j -= 1
		out.append(pts[j])
		i = j
	return out


## Ist die Strecke frei (mit 0,3 m Abstand zu beiden Seiten, damit niemand an Ecken schrammt)?
func clear_line(a: Vector2, b: Vector2) -> bool:
	var d := b - a
	var ln := d.length()
	if ln < 0.01:
		return true
	var side := d.orthogonal() / ln * 0.3
	var steps := int(ceil(ln / (RES * 0.25)))
	for k in steps + 1:
		var p := a + d * (float(k) / steps)
		for o in [Vector2.ZERO, side, -side]:
			var c := cell_of(p + o)
			if not inside(c) or astar.is_point_solid(c):
				return false
	return true
