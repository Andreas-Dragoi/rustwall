extends Node3D
## Stadtruinen (Paket Z2): Zonen-Mechanik der Expedition in Gebiet 9. Gehört zu expedition.gd (nur wenn adef.key == "stadt").
##   Straßen   Raster aus Straßenkacheln (Blender: p_st_road, p_st_cross) mit Autowracks, Laternen, Bushaltestellen, Litfaßsäulen,
##             Unkraut; Hochhausruinen im Außenring und als Skyline hinter dem Kartenrand.
##   Dächer    DW.ROOFS Dachhäuser (p_st_roof_1/2) mit Feuertreppe. Für Gegner sind Haus und Treppe fest (field.solid); der Held darf
##             hinauf: field.deck (1 = Dach, 2 = obere Treppe, 3 = Treppenfuß), field.deck_up (der Held ist auf Treppe oder Dach),
##             field.blocks_hero(). Oben (hero.perch): Nahkämpfer erreichen ihn nicht (horde.gd, hero.hurt → roof_safe), nur Flieger,
##             Fernkämpfer und Kletterer (Funkenspinnen klettern an die Dachkante und schocken); Reichweite × ROOF_RANGE, Schaden ×
##             ROOF_DMG. Wer über die Dachkante läuft, springt hinunter.
##   U-Bahn    DW.SUBWAY_LINES Linien, je ein Eingang in der Landezone bzw. im Mittelring und einer im Außenring. Mit Strom und nach dem
##             Großangriff: auf dem Einstieg stehen bleiben → ans andere Ende. Gegner fahren nicht mit (Abkürzung nur für den Helden).
##   Notstrom  je Linie ein Generator beim inneren Eingang: daneben stehen bleiben schaltet ihn ein. Er versorgt die Linie und alle
##             Ampeln im Umkreis DW.GEN_RANGE.
##   Ampeln    an Kreuzungen; mit Strom Grün → Gelb → Rot, bei Rot bleiben Maschinen im Umkreis stehen. Ohne Strom blinkt Gelb.
##   Gewitter  (exp_world.gd, Ereignis „gewitter“): set_blackout() – Stromausfall, bis das Gewitter vorbei ist.
## Ablauf wie exp_vulkan.gd: pre_generate() (vor den Kulissen: Häuser, Stationen, Generatoren, Ampeln, Wracks sperren ihre Felder),
## decor() (Straßen und Kleinkram, vor scatter_commit), setup() (Knoten mit Schaltteilen, Anzeige), tick() jedes Bild.

const D = preload("res://src/data.gd")
const DW = preload("res://src/data_welt.gd")
const Models = preload("res://src/models.gd")
const MK = preload("res://src/mk.gd")

const TILE := 8.0
const STAIR_LEN := 4.0
const AMPEL_FLASH := 0.5

var ex: Node3D
var rng := RandomNumberGenerator.new()
var fix := RandomNumberGenerator.new()      # fest je Gebiet (Landezone)
var deck := PackedByteArray()
var xs: Array = []                           # Straßenlinien (x = konstant, Straße läuft entlang z)
var zs: Array = []                           # Straßenlinien (z = konstant, Straße läuft entlang x)
var roads: Array = []                        # [Mitte, Gier, Kreuzung?]
var roofs: Array = []                        # {c, k, kind, cells}
var stations: Array = []                     # {p, yaw, door, line, end, n, gate, sign}
var gens: Array = []                         # {p, line, on, n, lamp, fan}
var ampels: Array = []                       # {p, yaw, n, lights, gen, t, ph}
var props: Array = []                        # [modell, Mitte, Gier] (Wracks, Haltestellen, Säulen, Hochhäuser)
var blackout := false
var perched := false
var hero_h := 0.0
var rides := 0
var stops := 0
var zaps := 0
var log: Array[String] = []

var _gen_was: Array = []
var _ride_cd := 0.0
var _hold_t := 0.0
var _hold_key := ""
var _ring: MeshInstance3D
var _fill: MeshInstance3D
var _fade: ColorRect
var _fade_t := -1.0
var _ride_to = null
var _amp_t := 0.0
var _climb_t := 0.0
var _flash_t := 0.0
var _fam := PackedByteArray()                # 1 = Maschine (Typ-Index), 2 = Maschine, die nie anhält (Boss, Miniboss)
var _climber := PackedByteArray()
var _zap_cd := {}
var _hung := {}
var _base_r := 0.0
var _boost_r := -1.0
var _base_d := 0.0
var _boost_d := -1.0
var _told := {}
var _land_from := 0.0
var _shot_t := 0.0


func _ready() -> void:
	name = "Stadt"


# ================================================================= Aufbau (vor den Kulissen)
func pre_generate(e: Node3D) -> void:
	ex = e
	rng.seed = hash("rustwall-stadt|%d" % P.day_index())
	if G.arg("seed") != "":
		rng.seed = int(G.arg("seed")) + 919
	fix.seed = hash("rustwall-stadt|fest")
	var f = ex.field
	deck.resize(f.solid.size())
	deck.fill(0)
	f.deck = deck
	var lim: float = ex.HALFM - 6.0
	var v: float = DW.CITY_OFF
	while v - DW.CITY_GRID > -lim:
		v -= DW.CITY_GRID
	while v < lim:
		xs.append(v)
		zs.append(v)
		v += DW.CITY_GRID
	_plan_roads()
	_place_roofs()
	_place_subway()
	_place_ampels()
	_place_props()
	f.dirty = true


## Lage der Straßenkacheln: Linien in beiden Richtungen, Kreuzungen dort, wo sie sich treffen.
func _plan_roads() -> void:
	var lim: float = ex.HALFM - 6.0
	# Kacheln von den Kreuzungen aus abzählen, damit sie genau anschließen (Linienabstand = 6 Kacheln)
	var n := int(ceil(2.0 * lim / TILE)) + 2
	for x in xs:
		for j in range(-n, n + 1):
			var z: float = float(zs[0]) + j * TILE
			if absf(z) > lim:
				continue
			var p := Vector2(x, z)
			if not _is_cross(z, zs) and _road_ok(p):
				roads.append([p, 0.0, false])
	for z0 in zs:
		for j in range(-n, n + 1):
			var x2: float = float(xs[0]) + j * TILE
			if absf(x2) > lim:
				continue
			var p2 := Vector2(x2, z0)
			if not _is_cross(x2, xs) and _road_ok(p2):
				roads.append([p2, PI * 0.5, false])
	for x1 in xs:
		for z1 in zs:
			var p3 := Vector2(x1, z1)
			if _road_ok(p3):
				roads.append([p3, 0.0, true])


static func _is_cross(v: float, lines: Array) -> bool:
	for l in lines:
		if absf(v - float(l)) < 1.0:
			return true
	return false


func _road_ok(p: Vector2) -> bool:
	var oc: Vector2 = ex.outpost.C
	if absf(p.x - oc.x) < 13.0 and absf(p.y - oc.y) < 13.0:
		return false
	var r := p.length()
	if r > D.EXP_RING_LAND - 3.0 and r < D.EXP_RING_LAND + D.EXP_RING_W + 3.0 and not ex._near_passage(p, 5.0):
		return false
	var lm: Vector2 = ex.welt.lm_p if ex.welt != null else Vector2.INF
	if lm != Vector2.INF and p.distance_to(lm) < 11.0:
		return false
	return absf(p.x) < ex.HALFM - 5.0 and absf(p.y) < ex.HALFM - 5.0


## Abstand zur nächsten Straßenlinie (Mitte der Fahrbahn).
func road_dist(p: Vector2) -> float:
	var best := 999.0
	for x in xs:
		best = minf(best, absf(p.x - x))
	for z in zs:
		best = minf(best, absf(p.y - z))
	return best


# ---------------------------------------------------------------- Dachhäuser
## Weltpunkt aus Hauskoordinaten (x quer, z nach vorn = zur Treppe) bei Drehung k × 90°.
static func l2w(c: Vector2, k: int, lx: float, lz: float) -> Vector2:
	var a := k * PI * 0.5
	return c + Vector2(lx * cos(a) + lz * sin(a), -lx * sin(a) + lz * cos(a))


static func w2l(c: Vector2, k: int, p: Vector2) -> Vector2:
	var a := k * PI * 0.5
	var d := p - c
	return Vector2(d.x * cos(a) - d.y * sin(a), d.x * sin(a) + d.y * cos(a))


func _place_roofs() -> void:
	var want: int = DW.ROOFS
	var land := 0
	for tries in 400:
		if roofs.size() >= want:
			break
		var inner := land < 1 and tries < 120
		var r2: RandomNumberGenerator = fix if inner else rng
		var c: Vector2
		if inner:
			c = Vector2.from_angle(r2.randf() * TAU) * r2.randf_range(14.0, D.EXP_RING_LAND - 12.0)
		else:
			c = Vector2(r2.randf_range(-ex.HALFM + 14.0, ex.HALFM - 14.0), r2.randf_range(-ex.HALFM + 14.0, ex.HALFM - 14.0))
			if c.length() < D.EXP_RING_LAND + D.EXP_RING_W + 9.0:
				continue
		var k := r2.randi_range(0, 3)
		# auf das Raster legen: 10 m Seite mittig auf ungeraden, 8 m Seite auf geraden Metern
		var ext := Vector2(5.0, 4.0) if k % 2 == 0 else Vector2(4.0, 5.0)
		c = Vector2(_snap(c.x, ext.x), _snap(c.y, ext.y))
		if _roof_ok(c, k):
			_add_roof(c, k, (roofs.size() % 2) + 1)
			if inner:
				land += 1


static func _snap(v: float, half: float) -> float:
	# half 5 → Mitte ungerade, half 4 → Mitte gerade (Zellen 2 m, Ursprung −120)
	var base := roundf(v / 2.0) * 2.0
	return base + (1.0 if int(half) % 2 == 1 else 0.0)


func _roof_ok(c: Vector2, k: int) -> bool:
	var f = ex.field
	if c.distance_to(ex.outpost.C) < 22.0 or c.length() < 16.0 or ex._near_passage(c, 12.0):
		return false
	var r := c.length()
	if r > D.EXP_RING_LAND - 9.0 and r < D.EXP_RING_LAND + D.EXP_RING_W + 9.0:
		return false
	var lm: Vector2 = ex.welt.lm_p if ex.welt != null else Vector2.INF
	if lm != Vector2.INF and c.distance_to(lm) < 18.0:
		return false
	for o in roofs:
		if c.distance_to(o.c) < 22.0:
			return false
	for s in stations:
		if c.distance_to(s.p) < 14.0:
			return false
	# Haus, Treppe und ein Rand von 2 m frei, nicht auf der Fahrbahn
	for lx in range(-7, 8):
		for lz in range(-6, 11):
			var p := l2w(c, k, lx, lz)
			if not f.in_bounds(p, 6.0) or f.is_solid(p):
				return false
			if absf(lx) <= 5.0 and lz >= -4.0 and lz <= 8.0 and road_dist(p) < 4.2:
				return false
	return true


func _add_roof(c: Vector2, k: int, kind: int) -> void:
	var f = ex.field
	var cells := PackedInt32Array()
	for lx in range(-6, 7):
		for lz in range(-5, 10):
			var p := l2w(c, k, lx + 0.5, lz + 0.5)
			var i: int = f.idx(p)
			if i < 0 or cells.has(i):
				continue
			var q := w2l(c, k, f.center(i))
			var dv := 0
			if absf(q.x) < 5.0 and absf(q.y) < 4.0:
				dv = 1
			elif q.x > 1.0 and q.x < 5.0 and q.y > 4.0 and q.y < 8.0:
				dv = 3 if q.y > 6.0 else 2
			if dv > 0:
				deck[i] = dv
				f.solid[i] = 1
				cells.append(i)
	roofs.append({"c": c, "k": k, "kind": kind, "cells": cells})


## Höhe des Bodens unter p (0 = Straße, ROOF_H = Dach), Treppe dazwischen.
func deck_height(p: Vector2) -> float:
	var i: int = ex.field.idx(p)
	if i < 0 or i >= deck.size() or deck[i] == 0:
		return 0.0
	if deck[i] == 1:
		return DW.ROOF_H
	for r in roofs:
		var q := w2l(r.c, int(r.k), p)
		if q.x > 0.5 and q.x < 5.5 and q.y > 3.5 and q.y < 8.5:
			return DW.ROOF_H * clampf((8.0 - q.y) / STAIR_LEN, 0.0, 1.0)
	return DW.ROOF_H


func on_roof(p: Vector2) -> bool:
	var i: int = ex.field.idx(p)
	return i >= 0 and i < deck.size() and deck[i] == 1


# ---------------------------------------------------------------- U-Bahn und Notstrom
func _place_subway() -> void:
	for line in DW.SUBWAY_LINES:
		var a_rng: RandomNumberGenerator = fix if line == 0 else rng
		var made := false
		for tries in 60:
			var ang := a_rng.randf() * TAU
			var ra := a_rng.randf_range(26.0, D.EXP_RING_LAND - 8.0) if line == 0 else a_rng.randf_range(D.EXP_RING_LAND + 14.0, D.EXP_RING_MID - 8.0)
			var pa := _cell_mid(Vector2.from_angle(ang) * ra)
			var angb := ang + PI + rng.randf_range(-0.7, 0.7)
			var pb := _cell_mid(Vector2.from_angle(angb) * rng.randf_range(96.0, 106.0))
			if not _station_ok(pa) or not _station_ok(pb):
				continue
			var ya := _face_yaw(pa)
			var yb := _face_yaw(pb)
			var sa := _add_station(pa, ya, line, 0)
			var sb := _add_station(pb, yb, line, 1)
			sa["other"] = stations.size() - 1
			sb["other"] = stations.size() - 2
			# Generator neben dem inneren Eingang
			var gp = null
			for t2 in 30:
				var q: Vector2 = pa + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(6.0, 9.0)
				q = _cell_mid(q)
				if _free_circle(q, 2.2) and road_dist(q) > 4.5 and q.distance_to(ex.outpost.C) > 17.0 and not ex._near_passage(q, 7.0):
					gp = q
					break
			if gp == null:
				gp = pa + (pa - ex.outpost.C).normalized() * 7.0
			ex.field.block_circle(gp, 1.1)
			gens.append({"p": gp, "line": line, "on": false, "n": null, "lamp": null, "fan": null})
			made = true
			break
		if not made:
			log.append("subway_missing:%d" % line)


func _cell_mid(p: Vector2) -> Vector2:
	var i: int = ex.field.idx(p)
	return ex.field.center(i) if i >= 0 else p


func _station_ok(p: Vector2) -> bool:
	if p.distance_to(ex.outpost.C) < 24.0 or p.length() < 14.0 or ex._near_passage(p, 9.0):
		return false
	if absf(p.x) > ex.HALFM - 12.0 or absf(p.y) > ex.HALFM - 12.0:
		return false
	var lm: Vector2 = ex.welt.lm_p if ex.welt != null else Vector2.INF
	if lm != Vector2.INF and p.distance_to(lm) < 16.0:
		return false
	for s in stations:
		if p.distance_to(s.p) < 30.0:
			return false
	return _free_circle(p, 5.0) and road_dist(p) > 5.0


func _free_circle(p: Vector2, r: float) -> bool:
	var f = ex.field
	var x := -r
	while x <= r:
		var z := -r
		while z <= r:
			if Vector2(x, z).length() <= r and f.is_solid(p + Vector2(x, z)):
				return false
			z += 1.0
		x += 1.0
	return f.in_bounds(p, r + 2.0)


## Blickrichtung des Einstiegs: zur Kartenmitte (der Held kommt meist von dort).
func _face_yaw(p: Vector2) -> float:
	var to := -p.normalized()
	return atan2(to.x, to.y)


func _add_station(p: Vector2, yaw: float, line: int, end: int) -> Dictionary:
	var f = ex.field
	var fwd := Vector2(sin(yaw), cos(yaw))
	var side := fwd.orthogonal()
	# Grundfläche 3,6 × 5 m (Einstieg vorn) sperren
	for a in [-1.2, 0.0, 1.2]:
		for b in [-2.0, -1.0, 0.0, 1.0, 2.0]:
			var q: Vector2 = p + side * a + fwd * b
			var i: int = f.idx(q)
			if i >= 0:
				f.solid[i] = 1
	var door: Vector2 = p + fwd * 3.6
	var s := {"p": p, "yaw": yaw, "door": door, "line": line, "end": end, "n": null, "gate": null, "sign": null, "other": -1}
	stations.append(s)
	return s


func line_powered(line: int) -> bool:
	if blackout:
		return false
	for g in gens:
		if int(g.line) == line and bool(g.on):
			return true
	return false


## Strom für einen Punkt (Ampeln): ein eingeschalteter Generator in Reichweite.
func powered_at(p: Vector2) -> bool:
	if blackout:
		return false
	for g in gens:
		if bool(g.on) and p.distance_to(g.p) < DW.GEN_RANGE:
			return true
	return false


# ---------------------------------------------------------------- Ampeln, Wracks, Stadtmöbel, Hochhäuser
func _place_ampels() -> void:
	var cands: Array = []
	for rd in roads:
		if bool(rd[2]):
			cands.append(rd[0])
	cands.shuffle()
	for c in cands:
		if ampels.size() >= DW.AMPELS:
			break
		var corner := Vector2(3.4 * (1.0 if rng.randf() < 0.5 else -1.0), 3.4 * (1.0 if rng.randf() < 0.5 else -1.0))
		var p: Vector2 = c + corner
		if ex.field.is_solid(p) or p.length() < 10.0:
			continue
		var yaw := atan2(-corner.x, -corner.y)              # Lichter zur Kreuzung
		ampels.append({"p": p, "yaw": yaw, "n": null, "lights": [], "gen": -1, "t": rng.randf() * 10.0, "ph": 0})


func _place_props() -> void:
	var f = ex.field
	var oc: Vector2 = ex.outpost.C
	# Autowracks auf den Fahrbahnen
	var lane: Array = []
	for rd in roads:
		if not bool(rd[2]):
			lane.append(rd)
	lane.shuffle()
	var cars := 0
	for rd in lane:
		if cars >= 16:
			break
		var c: Vector2 = rd[0]
		var along := Vector2(0, 1) if float(rd[1]) == 0.0 else Vector2(1, 0)
		var p: Vector2 = c + along.orthogonal() * rng.randf_range(-1.6, 1.6) + along * rng.randf_range(-2.0, 2.0)
		if p.length() < 12.0 or p.distance_to(oc) < 16.0 or ex._near_passage(p, 8.0) or not _free_circle(p, 2.0):
			continue
		var kind := 1 if rng.randf() < 0.65 else 2
		var yaw := atan2(along.x, along.y) + rng.randf_range(-0.5, 0.5) + (PI if rng.randf() < 0.5 else 0.0)
		props.append(["p_st_car_%d" % kind, p, yaw])
		f.block_circle(p, 1.3 if kind == 1 else 1.8)
		cars += 1
	# Bushaltestellen und Litfaßsäulen am Straßenrand
	var n_bus := 0
	var n_col := 0
	for rd in lane:
		if n_bus >= 5 and n_col >= 6:
			break
		var c2: Vector2 = rd[0]
		var along2 := Vector2(0, 1) if float(rd[1]) == 0.0 else Vector2(1, 0)
		var sd := 1.0 if rng.randf() < 0.5 else -1.0
		var p2: Vector2 = c2 + along2.orthogonal() * sd * 5.4
		if p2.distance_to(oc) < 16.0 or p2.length() < 12.0 or ex._near_passage(p2, 8.0) or not _free_circle(p2, 2.4):
			continue
		var face := atan2(-along2.orthogonal().x * sd, -along2.orthogonal().y * sd)
		if n_bus < 5 and rng.randf() < 0.5:
			props.append(["p_st_bushalt", p2, face + PI])
			f.block_circle(p2, 1.4)
			n_bus += 1
		elif n_col < 6:
			props.append(["p_st_litfass", p2, rng.randf() * TAU])
			f.block_circle(p2, 0.8)
			n_col += 1
	# Hochhausruinen im Außenring
	var tall := 0
	for tries in 80:
		if tall >= 5:
			break
		var p3 := Vector2(rng.randf_range(-ex.HALFM + 14.0, ex.HALFM - 14.0), rng.randf_range(-ex.HALFM + 14.0, ex.HALFM - 14.0))
		if p3.length() < 92.0 or road_dist(p3) < 11.0 or ex._near_passage(p3, 10.0) or not _free_circle(p3, 8.5):
			continue
		var ok := true
		for s in stations:
			if p3.distance_to(s.p) < 14.0:
				ok = false
		for r in roofs:
			if p3.distance_to(r.c) < 16.0:
				ok = false
		if not ok:
			continue
		props.append(["p_st_hochhaus_%d" % (tall % 2 + 1), p3, float(rng.randi_range(0, 3)) * PI * 0.5])
		f.block_rect(p3 - Vector2(6.4, 6.4), p3 + Vector2(6.4, 6.4))
		tall += 1


# ================================================================= Kulissen (vor scatter_commit)
func decor() -> void:
	var f = ex.field
	for rd in roads:
		ex.scatter("p_st_cross" if bool(rd[2]) else "p_st_road", Vector3(rd[0].x, 0, rd[0].y), float(rd[1]))
	for r in roofs:
		ex.scatter("p_st_roof_%d" % int(r.kind), Vector3(r.c.x, 0, r.c.y), int(r.k) * PI * 0.5)
	for pr in props:
		ex.scatter(String(pr[0]), Vector3(pr[1].x, 0, pr[1].y), float(pr[2]))
	# Laternen am Gehweg (nicht auf Kreuzungen, nicht in festen Feldern)
	var i := 0
	for rd in roads:
		i += 1
		if bool(rd[2]) or i % 2 == 0:
			continue
		var along := Vector2(0, 1) if float(rd[1]) == 0.0 else Vector2(1, 0)
		var sd := 1.0 if i % 4 == 1 else -1.0
		var q: Vector2 = rd[0] + along.orthogonal() * sd * 3.6
		if not f.is_solid(q):
			var yaw := atan2(-along.orthogonal().x * sd, -along.orthogonal().y * sd) - PI * 0.5
			ex.scatter("p_st_laterne", Vector3(q.x, 0.1, q.y), yaw)
	# Skyline: Hochhausruinen hinter dem Kartenrand
	for k in 16:
		var a := TAU * k / 16.0 + rng.randf_range(-0.1, 0.1)
		var d := rng.randf_range(132.0, 150.0)
		var q2 := Vector2(cos(a), sin(a)) * d
		ex.scatter("p_st_hochhaus_%d" % (k % 2 + 1), Vector3(q2.x, 0, q2.y), rng.randi_range(0, 3) * PI * 0.5, rng.randf_range(1.0, 1.35))
	# Unkraut aus den Rissen
	for k2 in [220, 420, 640][G.quality()]:
		var q3 := Vector2(rng.randf_range(-110.0, 110.0), rng.randf_range(-110.0, 110.0))
		if f.is_solid(q3) or q3.distance_to(ex.outpost.C) < 12.0:
			continue
		if road_dist(q3) < 4.0 or rng.randf() < 0.35:
			ex.scatter("p_st_weed", Vector3(q3.x, 0.02, q3.y), rng.randf() * TAU, rng.randf_range(0.7, 1.3))


# ================================================================= nach dem Aufbau: Knoten mit Schaltteilen, Anzeige
func setup() -> void:
	for s in stations:
		var n: Node3D = _model("p_st_ubahn")
		n.position = Vector3(s.p.x, 0, s.p.y)
		n.rotation.y = float(s.yaw)
		add_child(n)
		s.n = n
		s.gate = Models.find(n, "gate")
		s.sign = Models.find(n, "sign_glow")
	for g in gens:
		var n2: Node3D = _model("p_st_generator")
		n2.position = Vector3(g.p.x, 0, g.p.y)
		var to: Vector2 = ex.outpost.C - g.p
		n2.rotation.y = atan2(to.x, to.y)
		add_child(n2)
		g.n = n2
		g.lamp = Models.find(n2, "lamp_glow")
		g.fan = Models.find(n2, "fan")
	for a in ampels:
		var n3: Node3D = _model("p_st_ampel")
		n3.position = Vector3(a.p.x, 0, a.p.y)
		n3.rotation.y = float(a.yaw)
		add_child(n3)
		a.n = n3
		a.lights = [Models.find(n3, "red_glow"), Models.find(n3, "yellow_glow"), Models.find(n3, "green_glow")]
		var best := 9999.0
		for gi in gens.size():
			var dd: float = a.p.distance_to(gens[gi].p)
			if dd < best:
				best = dd
				a.gen = gi
	_fam.resize(D.ENEMIES.size())
	_climber.resize(D.ENEMIES.size())
	for t in D.ENEMIES.size():
		var def: Dictionary = D.ENEMIES[t]
		if String(def.family) == "maschinen":
			_fam[t] = 2 if String(def.role) in ["boss", "miniboss"] else 1
		_climber[t] = 1 if bool(def.get("climb", false)) else 0
	_ring = ex.ring_mesh(1.4, Color("4AD8FF"))
	_ring.visible = false
	_fill = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 0.04
	cm.radial_segments = 20
	cm.rings = 1
	_fill.mesh = cm
	_fill.material_override = MK.glow(Color(0.3, 0.85, 1.0, 0.45), true)
	_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fill.visible = false
	add_child(_fill)
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)
	_refresh_power()
	log.append("setup:%d/%d/%d/%d" % [roofs.size(), stations.size(), gens.size(), ampels.size()])


func _model(m: String) -> Node3D:
	return Models.glb(m) if Models.has_glb(m) else Node3D.new()


# ================================================================= Bild für Bild
func tick(dt: float, pp: Vector2) -> void:
	if _shot_t >= 0.0:
		_shot_t += dt
		if _shot_t > 0.5 and _shot_t - dt <= 0.5:
			_shot_setup(G.arg("stadt"), 0)
		if _shot_t > 1.6:
			_shot_t = -1.0
			_shot_setup(G.arg("stadt"), 1)
	_tick_hero(dt, pp)
	_tick_hold(dt, pp)
	_tick_fade(dt)
	for g in gens:
		if bool(g.on) and not blackout and g.fan != null:
			g.fan.rotate_object_local(Vector3.RIGHT, dt * 18.0)
	_amp_t -= dt
	if _amp_t <= 0.0:
		_amp_t = 0.25
		_tick_ampels(0.25)
	_climb_t -= dt
	if _climb_t <= 0.0:
		_climb_t = 0.2
		_tick_climbers(0.2, pp)
	if blackout:
		_flash_t -= dt
		if _flash_t <= 0.0 and ex.sun != null:
			_flash_t = rng.randf_range(2.5, 6.0)
			var e0: float = ex.sun.light_energy
			ex.sun.light_energy = e0 + 1.6                   # Wetterleuchten (der Tageslauf stellt es im nächsten Bild zurück)
			Sfx.play("ev_thunder_far", -10.0, rng.randf_range(0.85, 1.1), 0.2)


# ---------------------------------------------------------------- Held: Treppe, Dach, Sprung
func _tick_hero(dt: float, pp: Vector2) -> void:
	var h = ex.hero
	var f = ex.field
	if h == null:
		return
	var i: int = f.idx(pp)
	var d: int = deck[i] if i >= 0 and i < deck.size() else 0
	f.deck_lock = h.mounted and d == 0
	f.deck_up = d != 0 and not h.mounted
	var want := 0.0
	if d != 0 and not h.mounted and h.alive:
		want = deck_height(pp)
	if want >= hero_h:
		hero_h = move_toward(hero_h, want, dt * 9.0)
		_land_from = 0.0
	else:
		if _land_from <= 0.0:
			_land_from = hero_h
		hero_h = move_toward(hero_h, want, dt * DW.ROOF_H / DW.ROOF_FALL)
		if hero_h <= want + 0.001 and _land_from > 1.5 and want < 0.1:
			_land_from = 0.0
			Sfx.play("roof_land", -6.0, 1.0, 0.1)
			ex.fx.puff(Vector3(pp.x, 0.1, pp.y), Color(0.75, 0.72, 0.66), 10, 1.2)
			log.append("jump")
	if not h.mounted:
		h.body.position.y = hero_h
	h.perch = hero_h
	var up: bool = hero_h >= DW.ROOF_H * 0.85 and h.alive
	if up != perched:
		perched = up
		if up:
			log.append("roof")
			_tell("roof", "Auf dem Dach! Nahkämpfer kommen nicht hoch – und du triffst weiter.")
			Sfx.play("roof_up", -8.0)
	_apply_boost(h)
	if d == 3 and not perched:
		_tell("stair", "Feuertreppe: Oben auf dem Dach erreichen dich nur Flieger, Schützen und Funkenspinnen.")


## Dach-Vorteil: Reichweite und Schaden. Wechselt der Held oben die Waffe, gilt der neue Wert als Grundlage.
func _apply_boost(h) -> void:
	if perched:
		if absf(float(h.wrange) - _boost_r) > 0.001:
			_base_r = float(h.wrange)
			h.wrange = _base_r * DW.ROOF_RANGE
			_boost_r = float(h.wrange)
		if absf(float(h.dmg) - _boost_d) > 0.001:
			_base_d = float(h.dmg)
			h.dmg = _base_d * DW.ROOF_DMG
			_boost_d = float(h.dmg)
	else:
		if _boost_r >= 0.0:
			if absf(float(h.wrange) - _boost_r) < 0.001:
				h.wrange = _base_r
			_boost_r = -1.0
		if _boost_d >= 0.0:
			if absf(float(h.dmg) - _boost_d) < 0.001:
				h.dmg = _base_d
			_boost_d = -1.0


## Für hero.hurt: Nahkämpfer (nicht fliegend, ohne Fernangriff) treffen einen Helden auf dem Dach nicht.
static func roof_safe(hero, from) -> bool:
	if from == null or float(hero.perch) < 1.0 or not (from is Object) or from.get("rng") == null:
		return false
	return float(from.rng) <= 0.0 and not bool(from.fly)


# ---------------------------------------------------------------- Stehen bleiben: Generator einschalten, U-Bahn fahren
func _tick_hold(dt: float, pp: Vector2) -> void:
	_ride_cd -= dt
	var h = ex.hero
	var key := ""
	var at := Vector2.ZERO
	var need := 1.0
	if h.alive and not h.mounted and not perched and _fade_t < 0.0:
		for gi in gens.size():
			var g: Dictionary = gens[gi]
			if pp.distance_to(g.p) < DW.GEN_R:
				if bool(g.on) and not blackout:
					continue
				if blackout:
					_tell("gen_storm", "Bei Gewitter springt kein Generator an. Warte, bis es vorbei ist.")
					continue
				key = "gen:%d" % gi
				at = g.p
				need = DW.GEN_HOLD
				_tell("gen", "Notstrom-Generator: Bleib kurz stehen, um ihn einzuschalten.")
		for si in stations.size():
			var s: Dictionary = stations[si]
			if pp.distance_to(s.door) < DW.SUBWAY_R:
				if not ex._barriers_open():
					_tell("sub_closed", "Der U-Bahn-Schacht ist verschüttet – erst nach dem Großangriff frei.")
				elif not line_powered(int(s.line)):
					_tell("sub_power", "U-Bahn: Kein Strom. Wirf den Notstrom-Generator am inneren Eingang an.")
				elif _ride_cd <= 0.0:
					key = "sub:%d" % si
					at = s.door
					need = DW.SUBWAY_HOLD
	if key == "" or key != _hold_key or h.speed_now > 1.2:
		_hold_t = maxf(0.0, _hold_t - dt * 3.0) if key == _hold_key else 0.0
		_hold_key = key
	else:
		_hold_t += dt
	var show := key != ""
	_ring.visible = show
	_fill.visible = show and _hold_t > 0.0
	if show:
		_ring.position = Vector3(at.x, 0.12, at.y)
		var k := clampf(_hold_t / need, 0.0, 1.0)
		_fill.position = Vector3(at.x, 0.11, at.y)
		_fill.scale = Vector3(1.4 * k + 0.01, 1.0, 1.4 * k + 0.01)
		if _hold_t >= need:
			_hold_t = 0.0
			_hold_key = ""
			if key.begins_with("gen:"):
				switch_gen(int(key.get_slice(":", 1)), true)
			else:
				ride(int(key.get_slice(":", 1)))


## Generator ein-/ausschalten (auch für Tests und Admin).
func switch_gen(gi: int, on: bool) -> void:
	if gi < 0 or gi >= gens.size():
		return
	var g: Dictionary = gens[gi]
	if bool(g.on) == on:
		return
	g.on = on
	if on:
		Sfx.play_at("gen_start", Vector3(g.p.x, 0, g.p.y), -2.0)
		ex.fx.puff(Vector3(g.p.x, 1.8, g.p.y), Color(0.5, 0.5, 0.55), 10, 1.0)
		P.toast.emit("Strom ist da! Die U-Bahn fährt, und die Ampeln in der Nähe schalten wieder.")
		log.append("gen_on")
		P.count_up("stadt_power", 1)
	_refresh_power()
	ex.state_changed.emit()


## Fahrt mit der U-Bahn von Station si zum anderen Eingang der Linie.
func ride(si: int) -> void:
	if si < 0 or si >= stations.size():
		return
	var s: Dictionary = stations[si]
	var o: int = int(s.other)
	if o < 0 or not line_powered(int(s.line)) or not ex._barriers_open():
		return
	_ride_to = stations[o]
	_fade_t = 0.0
	_ride_cd = DW.SUBWAY_CD
	Sfx.play("ubahn_ride", -3.0)
	log.append("ride")


func _tick_fade(dt: float) -> void:
	if _fade_t < 0.0:
		return
	_fade_t += dt
	var a := 0.0
	if _fade_t < 0.35:
		a = _fade_t / 0.35
	elif _fade_t < 0.75:
		a = 1.0
		if _ride_to != null:
			var t: Dictionary = _ride_to
			_ride_to = null
			var fwd := Vector2(sin(float(t.yaw)), cos(float(t.yaw)))
			var q: Vector2 = t.door + fwd * 1.4
			ex.hero.global_position = Vector3(q.x, 0, q.y)
			ex.cam.snap()
			rides += 1
			P.count_up("stadt_rides", 1)
			Sfx.play("ubahn_arrive", -4.0)
			if ex.has_method("_reveal"):
				ex._reveal(q)
	elif _fade_t < 1.1:
		a = 1.0 - (_fade_t - 0.75) / 0.35
	else:
		a = 0.0
		_fade_t = -1.0
		P.toast.emit("Mit der U-Bahn ans andere Ende der Stadt!")
	_fade.color = Color(0, 0, 0, a)


# ---------------------------------------------------------------- Strom, Ampeln, Gewitter
func _refresh_power() -> void:
	for g in gens:
		if g.lamp != null:
			g.lamp.visible = bool(g.on) and not blackout
	for s in stations:
		var p := line_powered(int(s.line))
		if s.sign != null:
			s.sign.visible = p
		if s.gate != null:
			s.gate.visible = not (p and ex._barriers_open())


## Gewitter: Stromausfall (alle Generatoren aus), danach springt wieder an, was vorher lief.
func set_blackout(on: bool) -> void:
	if blackout == on:
		return
	blackout = on
	log.append("blackout:%s" % on)
	_refresh_power()
	_tick_ampels(0.0)


func _tick_ampels(dt: float) -> void:
	_refresh_power()
	var red_at: Array = []
	var blink := int(Time.get_ticks_msec() / (AMPEL_FLASH * 1000.0)) % 2 == 0
	for a in ampels:
		var on := powered_at(a.p)
		var st := -1                                 # 0 rot, 1 gelb, 2 grün, -1 dunkel, 3 gelb blinkend
		if on:
			a.t = float(a.t) + dt
			var cyc: float = DW.AMPEL_CYCLE[0] + DW.AMPEL_CYCLE[1] + DW.AMPEL_CYCLE[2]
			var tt := fmod(float(a.t), cyc)
			if tt < DW.AMPEL_CYCLE[0]:
				st = 2
			elif tt < DW.AMPEL_CYCLE[0] + DW.AMPEL_CYCLE[1]:
				st = 1
			else:
				st = 0
				red_at.append(a.p)
			if st == 0 and int(a.ph) != 0:
				Sfx.play_at("ampel_red", Vector3(a.p.x, 0, a.p.y), -10.0)
			a.ph = st
		elif not blackout:
			st = 3
			a.ph = 3
		else:
			a.ph = -1
		var ls: Array = a.lights
		if ls.size() == 3:
			if ls[0] != null:
				ls[0].visible = st == 0
			if ls[1] != null:
				ls[1].visible = st == 1 or (st == 3 and blink)
			if ls[2] != null:
				ls[2].visible = st == 2
	if red_at.is_empty() or ex.horde == null:
		return
	for e in ex.horde.list:
		if e.st == 2 or e.t >= _fam.size() or _fam[e.t] != 1:
			continue
		for c in red_at:
			if e.p.distance_squared_to(c) < DW.AMPEL_R * DW.AMPEL_R:
				if e.stun <= 0.0:
					stops += 1
					if stops % 4 == 1:
						ex.fx.float_text(Vector3(e.p.x, 1.8 * e.sc + e.alt, e.p.y), "Rot!", Color("FF4A3A"))
				e.stun = maxf(e.stun, 0.4)
				e.v = Vector2.ZERO
				break


## Rote Ampel in der Nähe von p? (Tests, Testbot)
func red_near(p: Vector2) -> bool:
	for a in ampels:
		if int(a.ph) == 0 and p.distance_to(a.p) < DW.AMPEL_R:
			return true
	return false


# ---------------------------------------------------------------- Funkenspinnen klettern an die Dachkante
func _tick_climbers(dt: float, pp: Vector2) -> void:
	var hd = ex.horde
	if hd == null:
		return
	var near: Array = hd.in_radius(pp, 5.5) if perched else []
	var now := {}
	for e in near:
		if e.st == 2 or e.t >= _climber.size() or _climber[e.t] == 0:
			continue
		now[e] = true
		if not _hung.has(e):
			hd.loop_clip(e, "climb")
			Sfx.play_at("spider_climb", Vector3(e.p.x, 0, e.p.y), -10.0, 1.0, 0.2)
		e.alt = DW.ROOF_H - 0.9
		e.v = Vector2.ZERO
		var cd: float = float(_zap_cd.get(e, 0.3)) - dt
		if cd <= 0.0:
			cd = 1.1
			var def: Dictionary = D.ENEMIES[e.t]
			ex.fx.lightning(Vector3(e.p.x, e.alt + 0.6, e.p.y), Vector3(pp.x, DW.ROOF_H + 1.0, pp.y))
			Sfx.play_at("spark_zap", Vector3(pp.x, DW.ROOF_H, pp.y), -8.0, 1.0, 0.15)
			ex.hero.hurt(float(def.dmg) * float(e.dp) * 1.2, null)
			zaps += 1
		_zap_cd[e] = cd
	for e in _hung.keys():
		if not now.has(e):
			if e.st != 2:
				e.alt = 0.0
				hd.loop_clip(e, "")
			_zap_cd.erase(e)
	_hung = now


# ================================================================= Karte, Hinweise, Bilder
func map_points(out: Array) -> void:
	for s in stations:
		if ex._seen(s.p):
			out.append([s.p, "subway"])
	for g in gens:
		if ex._seen(g.p):
			out.append([g.p, "gen"])


func _tell(key: String, text: String) -> void:
	if _told.has(key) or G.autotest != "":
		return
	_told[key] = true
	P.toast.emit(text)


## Bilder und Prüfungen (--stadt=roof,stair,subway,power,storm,ampel,road): Außenbasis fertig, Held an den gewünschten Ort.
func _shot_setup(what: String, stage: int) -> void:
	if what == "":
		return
	var w := what.split(",")
	if stage == 0:
		if ("subway" in w or "power" in w or "open" in w or "storm" in w) and ex.phase != "explore":
			ex.admin_outpost_done()
		return
	if "power" in w:
		for gi in gens.size():
			switch_gen(gi, true)
	var to = null
	if ex.hero.mounted:
		ex.hero.dismount()
	if "roof" in w and roofs.size() > 0:
		var r: Dictionary = roofs[1 % roofs.size()]
		to = l2w(r.c, int(r.k), 0.0, 0.0)
		hero_h = DW.ROOF_H
	elif "stair" in w and roofs.size() > 0:
		var r2: Dictionary = roofs[1 % roofs.size()]
		to = l2w(r2.c, int(r2.k), 3.0, 10.5)
	elif "subway" in w and stations.size() > 0:
		to = stations[0].door + Vector2(sin(float(stations[0].yaw)), cos(float(stations[0].yaw))) * 2.5
	elif "gen" in w and gens.size() > 0:
		to = gens[0].p + Vector2(3.0, 0.0)
	elif "ampel" in w and ampels.size() > 0:
		to = ampels[0].p + Vector2(4.0, 4.0)
	if to != null:
		ex.hero.global_position = Vector3(to.x, 0, to.y)
		ex.cam.snap()
	if "storm" in w:
		ex.welt.start_event()
