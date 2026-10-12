extends "res://src/world.gd"
## Expedition (V3): Karte 240 × 240 m in drei Ringen. Ablauf in vier Phasen:
##   land     Ankommen: Rohstoffe abbauen, Münzen sammeln (die Landezone ist durch Sperren abgeschlossen)
##   build    Aufbauen: auf Bauplätze stellen, Rucksack fließt ab, Gebäude wachsen; Störangriffe alle 50 s
##   siege    Großangriff 75 s aus zwei Richtungen, am Ende ein Elitegegner
##   explore  Erkunden: Sperren lösen sich auf, Nebenaufgaben (poi.gd), Depot, Dämmerung, Heimkehr
## Steht die Außenbasis schon, beginnt der Besuch in Phase „explore“. Mission „befreiung“: belagerte Außenbasis
## (drei Wellen in vier Minuten). Grundriss und Stand der Außenbasis: outpost.gd; Bauplätze: pad.gd;
## Rohstoffquellen: resource_node.gd; Orte der Nebenaufgaben: poi.gd. Alle Zahlen in data.gd (EXP_*, OUTPOST_*).

const Outpost = preload("res://src/outpost.gd")
const ResNode = preload("res://src/resource_node.gd")
const Poi = preload("res://src/poi.gd")
const Backpack = preload("res://src/backpack.gd")
const CD = preload("res://src/companion_data.gd")
const CompanionFind = preload("res://src/companion_find.gd")
const ExpWorld = preload("res://src/exp_world.gd")
const DW = preload("res://src/data_welt.gd")
const WS = preload("res://src/welt_state.gd")

const N := 120                   # Kartenfelder je Seite (240 m)
const HALFM := 120.0
const EXT := 110.0
const START := Vector2.ZERO

signal state_changed
signal battle_ended

var area := 0
var mission := "expedition"
var diff := 0
var adef: Dictionary
var ea: Dictionary
var factor := 1.0
var phase := "land"
var loot := {}                   # Rucksack (coins = Feldmünzen)
var weight := 0.0
var cap := 220.0
var depot := {}                  # in dieser Expedition eingelagert (sicher)
var loads := 0                   # Ladungen ins Depot
var chests_found := 0
var result := {}
var nodes: Array = []            # ResNode
var pois: Array = []
var barriers: Array = []         # {cells, n, p, dir}
var outpost: Node3D
var hp_mult := 1.0
var dp_mult := 1.0
var loot_bonus := 1.0
var respawns_left := 3
var race_time := 0.0
var bounty_done := false
var rescued := false
var exit_k := 0.0                # (Anzeige) Haltebalken
var cage_k := 0.0
var siege_t := 0.0
var explore_t := 0.0
var dusk := 0
var raid_t := 0.0
var raid_warn := -1.0
var raid_from := Vector2.ZERO
var relief_wave := 0
var elite = null
var fog := PackedByteArray()
var fog_n := 24
var pack: Node3D                 # Rückenstapel, Ladekreis, abgeworfene Haufen (backpack.gd)
var mining = null                # ResNode, an dem gearbeitet wird
var welt: Node3D                 # Tageslauf, Wetter, Ereignisse, Wahrzeichen, Karawane, Nebenquest (exp_world.gd, Paket Welt)
var vulkan: Node3D               # Paket Z: Lavaströme und Hitze-Leiste der Vulkaninsel (exp_vulkan.gd), sonst null
var water_mesh: MeshInstance3D

var _fixed := RandomNumberGenerator.new()
var _reach: Array = []
var _passages: Array = []        # Winkel der Durchgänge
var _still := 0.0
var _hit_t := 0.0
var _pay_t := 0.0
var _chunks: Array = []          # fliegende Stücke {n, a, t, res, amt, to_pad}
var _chunk_pool: Array = []
var _chunk_mesh: BoxMesh
var _dead_t := -1.0
var _nav: RefCounted
var _nav_goal := Vector2(9999, 9999)
var _nav_rb := -1                  # Testbot: Stand des Wegfelds, für den _nav gilt
var _bot_t := 0.0
var _bot_target = null
var _bot_skill_t := 0.0
var _fog_t := 0.0
var _roam_t := 20.0
var _siege_wave_t := 0.0
var _show_t := -1.0              # Kamera zeigt die Durchgänge
var _show_i := 0
var _mix_sum := 0.0
var _heal_t := 0.0
var _lock_msg_t := 0.0
var _full_msg_t := 0.0
var _relief_t := 0.0
var _sun0 := 1.35
var _home_ring: MeshInstance3D
var _outer_solid := PackedByteArray()
var _depot_ring: MeshInstance3D


func init(a: int, m: String, d: int) -> void:
	area = clampi(a, 0, D.AREAS.size() - 1)
	mission = m if m == "befreiung" else "expedition"
	diff = d


func _ready() -> void:
	mode = "exp"
	adef = D.AREAS[area]
	ea = D.EXP_AREAS[area]
	factor = float(ea.factor)
	xp_factor = float(D.AREA_FACTOR[clampi(area, 0, D.AREA_FACTOR.size() - 1)]) * (1.0 + 0.5 * diff)
	var lvl := int(adef.level)
	hp_mult = (1.0 + 0.14 * (lvl - 1)) * float(D.DIFFS[diff].hp)
	dp_mult = (1.0 + 0.05 * (lvl - 1)) * (1.0 + 0.3 * diff)
	loot_bonus = float(D.DIFFS[diff].loot)
	preload("res://src/liveops.gd").apply_nightmare(self)    # Paket L: Albtraum+ (Modifikatoren, mehr Beute)
	setup_common(adef, Vector2(-HALFM, -HALFM), N, N, 2.0)
	field.slice_us = 1000                     # Paket G2: Wegfeld in Scheiben neu rechnen (keine 10-ms-Ruckler)
	_fixed.seed = hash("rustwall-outpost|%s" % String(adef.key))
	_rng.seed = hash("%d|%d|%d" % [area, diff, P.day_index()])
	if G.arg("seed") != "":
		_rng.seed = int(G.arg("seed"))
	cam.bounds = Rect2(-HALFM + 8, -HALFM + 8, HALFM * 2 - 16, HALFM * 2 - 16)
	horde.aggro_range = 13.0
	for v in adef.enemies:
		_mix_sum += float(v)
	fog.resize(fog_n * fog_n)
	_chunk_mesh = BoxMesh.new()
	_chunk_mesh.size = Vector3(0.28, 0.28, 0.28)
	var lv := P.outpost_level(String(adef.key))
	var open := lv >= 1
	_generate(open)
	# Phase und Startpunkt
	var hk := String(P.d.hero_sel)
	var sp := START
	if mission == "befreiung":
		phase = "relief"
		sp = outpost.C + outpost.s * 14.0
	elif open:
		phase = "explore"
		sp = outpost.C + outpost.s * 14.0
	elif outpost.built_ok("zentrale"):
		phase = "build"
		raid_t = D.EXP_RAID_EVERY * 0.6
	spawn_hero(hk, sp)
	cap = P.backpack_cap(hk, P.vehicle_sel()) + CD.active_carry(String(adef.key))
	hero.give_vehicle(P.vehicle_sel())
	hero.died.connect(_on_hero_died)
	respawns_left = D.EXP_RESPAWNS
	_update_goal()
	if phase == "build" and outpost.mandatory_done():
		_start_siege()
	running = true
	_sun0 = sun.light_energy
	welt.setup()                     # Umgebungsklang je Gebiet und Tageszeit kommt von dort
	if vulkan != null:
		vulkan.setup()
	Music.set_mood("battle")
	_reveal(hero.pos2())
	state_changed.emit()


# ================================================================= Karte
func _generate(open: bool) -> void:
	field.block_rect(Vector2(-HALFM, -HALFM), Vector2(HALFM, -HALFM + 3.9))
	field.block_rect(Vector2(-HALFM, HALFM - 3.9), Vector2(HALFM, HALFM))
	field.block_rect(Vector2(-HALFM, -HALFM), Vector2(-HALFM + 3.9, HALFM))
	field.block_rect(Vector2(HALFM - 3.9, -HALFM), Vector2(HALFM, HALFM))
	# ---- Außenbasis: fester Ort je Gebiet, Tor zeigt zur Landestelle
	var dirs: Array = [Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1)]
	var odir: Vector2 = dirs[_fixed.randi() % 4]
	var dist := 2 * _fixed.randi_range(int(D.EXP_OUTPOST_DIST[0] / 2), int(D.EXP_OUTPOST_DIST[1] / 2))
	var oc := START + odir * dist
	outpost = Outpost.new()
	add_child(outpost)
	outpost.setup(self, area, oc, -odir)
	# ---- Sperrring um die Landezone mit drei Durchgängen (fest je Gebiet)
	var oa := atan2(odir.y, odir.x)
	var a0 := _fixed.randf() * TAU
	for k in D.EXP_PASSAGES:
		var a := a0 + k * TAU / D.EXP_PASSAGES
		if absf(angle_difference(a, oa)) < 0.6:
			a += 0.9
		_passages.append(a)
	var r0 := D.EXP_RING_LAND
	var r1 := D.EXP_RING_LAND + D.EXP_RING_W
	var pass_cells: Array = []
	for i in _passages.size():
		pass_cells.append([])
	for i in N * N:
		var c: Vector2 = field.center(i)
		var d := c.length()
		if d < r0 or d > r1:
			continue
		var in_pass := -1
		for k in _passages.size():
			var ax := Vector2(cos(_passages[k]), sin(_passages[k]))
			if c.dot(ax) > 0.0 and absf(c.dot(ax.orthogonal())) < D.EXP_PASSAGE_W * 0.5:
				in_pass = k
		if in_pass >= 0:
			pass_cells[in_pass].append(i)
			if not open:
				field.solid[i] = 1
		else:
			field.solid[i] = 1
	var bname := "x_barrier_" + String(adef.key)
	for k in _passages.size():
		var ax2 := Vector2(cos(_passages[k]), sin(_passages[k]))
		var bp := ax2 * (r0 + D.EXP_RING_W * 0.5)
		var entry := {"cells": pass_cells[k], "p": bp, "dir": ax2, "n": null}
		if not open:
			var t := ax2.orthogonal()
			entry.n = place_model(bname, Vector3(bp.x, 0, bp.y), atan2(-t.y, t.x))
		barriers.append(entry)
	_ring_decor()
	welt = ExpWorld.new()
	add_child(welt)
	welt.pre_generate(self)          # Platz für das Wahrzeichen
	if String(adef.key) == "vulkan":
		vulkan = preload("res://src/exp_vulkan.gd").new()
		add_child(vulkan)
		vulkan.pre_generate(self)    # Lavaströme sperren ihre Felder, bevor Bäume und Felsen verteilt werden
	# ---- Hindernisse und Wasser außerhalb der Landezone (neu je Besuch), wenige in der Landezone (fest)
	var kind: String = adef.tree
	var tree_n: int = 3 if kind == "pine" else 2
	var rock_m := "p_rock_snow" if area == 5 else ("p_rock_lava" if area == 7 else "p_rock")
	var rock_n := 2 if area == 5 else 3
	if adef.water:
		for i in 9:
			var c2 := Vector2(_rng.randf_range(-EXT, EXT), _rng.randf_range(-EXT, EXT))
			if c2.length() > r1 + 10.0 and not _near_passage(c2, 14.0):
				field.block_circle(c2, _rng.randf_range(3.0, 6.0), true)
	for i in 330:
		var land := i < 30
		var rng: RandomNumberGenerator = _fixed if land else _rng
		var c3 := Vector2(rng.randf_range(-EXT, EXT), rng.randf_range(-EXT, EXT))
		if land:
			c3 = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(14.0, r0 - 4.0)
		elif c3.length() < r1 + 4.0:
			continue
		if c3.length() < 9.0 or c3.distance_to(oc) < 15.0 or _near_passage(c3, 9.0) or field.is_solid(c3):
			continue
		if rng.randf() < 0.3:
			var r := rng.randf_range(1.2, 2.4)
			scatter("%s_%d" % [rock_m, rng.randi_range(1, rock_n)], Vector3(c3.x, 0, c3.y), rng.randf() * TAU, r / 1.55)
			field.block_circle(c3, r * 0.85)
		else:
			for j in rng.randi_range(1, 3):
				var q := c3 + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))
				if q.length() > 8.0 and q.distance_to(oc) > 14.0 and not field.is_solid(q):
					scatter_var("p_tree_" + kind, tree_n, Vector3(q.x, 0, q.y), rng, 0.9, 1.35)
					field.block_circle(q, 0.9)
	for i in 300:
		var a2 := _rng.randf() * TAU
		var q2 := Vector2(cos(a2), sin(a2)) * _rng.randf_range(HALFM - 3.0, HALFM + 30.0) * 1.3
		if maxf(absf(q2.x), absf(q2.y)) > HALFM - 3.0:
			scatter_var("p_tree_" + kind, tree_n, Vector3(q2.x, 0, q2.y), _rng, 0.9, 1.5)
	field.clear_rect(oc - Vector2(11, 11), oc + Vector2(11, 11))
	welt.post_generate()
	_compute_reach()
	# ---- Boden mit Wegen: Start – Tor, Start – Durchgänge – Außenring
	var gate := oc - odir * 11.0
	var paths: Array = [PackedVector2Array([START, gate, oc])]
	for a3 in _passages:
		var ax3 := Vector2(cos(a3), sin(a3))
		paths.append(PackedVector2Array([START + ax3 * 6.0, ax3 * (r1 + 6.0), ax3 * 80.0 + ax3.orthogonal() * 12.0]))
	make_ground(Vector2(-HALFM, -HALFM), Vector2(HALFM * 2, HALFM * 2), paths, 1.4)
	var water_cells: Array = []
	for i in N * N:
		if field.water[i] == 1:
			water_cells.append(i)
	if water_cells.size() > 0:
		var ws := MK.begin()
		var wc: Color = Color("4A9FDC") if area != 4 and area != 6 else Color("6FB84A")
		for i in water_cells:
			var c4: Vector2 = field.center(i)
			MK.box(ws, Vector3(c4.x, 0.03, c4.y), Vector3(2.02, 0.06, 2.02), wc)
		var wm := MK.inst(ws, self)
		var wmat := ShaderMaterial.new()
		wmat.shader = load("res://shaders/water.gdshader")
		wmat.set_shader_parameter("noise_tex", ground_mat.get_shader_parameter("noise_tex"))
		if area == 4 or area == 6:
			wmat.set_shader_parameter("col_deep", Color("3F8A2E"))
			wmat.set_shader_parameter("col_light", Color("9ADB5A"))
		wm.material_override = wmat
		wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		water_mesh = wm
	_decor()
	if vulkan != null:
		vulkan.decor()
	scatter_commit()
	make_ambient(String(adef.key))
	place_model("p_flag_exit", Vector3(START.x + 3.0, 0, START.y + 2.0))
	place_model("p_signpost", Vector3(START.x - 2.5, 0, START.y - 3.0), 0.4)
	# ---- Außenbasis laden (Bauplätze, fertige Gebäude)
	outpost.load_state()
	outpost.built.connect(_on_built)
	# ---- Rohstoffquellen und Orte
	_place_landing_nodes()
	_place_outer_nodes()
	_place_pois()
	for i in 2:
		var gp = _pick(16.0, 8.0, [START, oc], r0 - 6.0)
		if gp != null:
			group(gp, 3, 6.0)
	# Solange die Sperren stehen, zählt für das Richtungsfeld nur die Landezone: der Rest gilt als fest
	# (spart rund 90 % Rechenzeit beim Neuberechnen; Wachen draußen bleiben an ihrem Ort).
	if not open:
		_outer_solid = field.solid.duplicate()
		var lim := D.EXP_RING_LAND + D.EXP_RING_W + 1.0
		for i in N * N:
			if field.center(i).length() > lim:
				field.solid[i] = 1
	_home_ring = ring_mesh(3.2, D.C_SKY)
	_home_ring.visible = false
	_depot_ring = ring_mesh(1.8, D.C_GOLD)
	_depot_ring.visible = false
	field.dirty = true


func _near_passage(p: Vector2, w: float) -> bool:
	for a in _passages:
		var ax := Vector2(cos(a), sin(a))
		var along := p.dot(ax)
		if along > 0.0 and absf(p.dot(ax.orthogonal())) < w and along > D.EXP_RING_LAND - 14.0 and along < D.EXP_RING_LAND + D.EXP_RING_W + 14.0:
			return true
	return false


## Natürliche Sperre rund um die Landezone (Kulissen; die Durchgänge haben eigene Modelle).
func _ring_decor() -> void:
	var kind: String = adef.tree
	var lush: bool = area in [0, 1, 3]
	var rock_m := "p_rock_snow" if area == 5 else ("p_rock_lava" if area == 7 else "p_rock")
	var rock_n := 2 if area == 5 else 3
	for row in 2:
		var r := D.EXP_RING_LAND + 0.9 + row * 2.2
		var steps := int(TAU * r / 2.3)
		for i in steps:
			var a := TAU * (float(i) + 0.5 * row) / steps
			var p := Vector2(cos(a), sin(a)) * r
			if _near_passage(p, D.EXP_PASSAGE_W * 0.5 + 0.6):
				continue
			var p3 := Vector3(p.x, 0, p.y)
			if lush and _fixed.randf() < 0.7:
				scatter_var("p_tree_" + kind, 3 if kind == "pine" else 2, p3, _fixed, 1.0, 1.4)
			elif area == 2 or area == 4:
				if _fixed.randf() < 0.5:
					scatter_var("p_wreck", 2, p3, _fixed, 1.0, 1.0)
				else:
					scatter("%s_%d" % [rock_m, _fixed.randi_range(1, rock_n)], p3, _fixed.randf() * TAU, _fixed.randf_range(1.1, 1.6))
			else:
				scatter("%s_%d" % [rock_m, _fixed.randi_range(1, rock_n)], p3, _fixed.randf() * TAU, _fixed.randf_range(1.1, 1.7))


func _decor() -> void:
	var lush: bool = area in [0, 1, 4, 6]
	for i in [700, 1400, 2200][G.quality()]:
		var q3 := Vector2(_rng.randf_range(-EXT, EXT), _rng.randf_range(-EXT, EXT))
		if field.is_solid(q3) or q3.distance_to(outpost.C) < 12.0:
			continue
		var p3 := Vector3(q3.x, 0, q3.y)
		var k := _rng.randf()
		if (area == 3 or area == 4 or area == 2) and k < 0.06:
			scatter("p_barrel_1" if _rng.randf() < 0.5 else "p_crate_1", p3, _rng.randf() * TAU)
		elif lush:
			if k < 0.6:
				scatter_var("p_grass", 2, p3, _rng, 0.8, 1.5)
			elif k < 0.8:
				scatter_var("p_flowers", 3, p3, _rng, 0.7, 1.1)
			elif k < 0.93:
				scatter_var("p_bush", 2, p3, _rng)
			else:
				scatter("p_mushroom_1", p3, _rng.randf() * TAU, _rng.randf_range(0.7, 1.2))
		elif area == 3 and k < 0.3:
			scatter_var("p_grass", 2, p3, _rng, 0.8, 1.2)
		elif k > 0.93 and area != 7:            # Vulkaninsel: eigene Kulissen (exp_vulkan.gd)
			scatter("p_log_1" if area != 5 else "p_stump_1", p3, _rng.randf() * TAU)


## Erreichbare Feldmitten vom Start aus (Sperren gelten als offen, damit auch der Außenring Punkte bekommt).
func _compute_reach() -> void:
	_reach.clear()
	var open := {}
	for b in barriers:
		for ci in b.cells:
			open[ci] = true
	var seen := {}
	var si: int = field.idx(START)
	var stack: Array = [si]
	seen[si] = true
	while stack.size() > 0:
		var ci2: int = stack.pop_back()
		var cx := ci2 % N
		var cz := int(ci2 / N)
		for o in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var nx: int = cx + o[0]
			var nz: int = cz + o[1]
			if nx < 0 or nz < 0 or nx >= N or nz >= N:
				continue
			var ni := nx + nz * N
			if not seen.has(ni) and (field.solid[ni] == 0 or open.has(ni)):
				seen[ni] = true
				stack.append(ni)
	for k in seen:
		_reach.append(field.center(k))


## Freier, erreichbarer Punkt: Abstand zum Start zwischen min_start und max_start, zu allen others mindestens min_other.
func _pick(min_start: float, min_other: float, others: Array, max_start := 999.0, rng: RandomNumberGenerator = null):
	if rng == null:
		rng = _rng
	for tries in 80:
		var p: Vector2 = _reach[rng.randi() % _reach.size()]
		var ds := p.length()
		if ds < min_start or ds > max_start:
			continue
		if absf(p.x) > HALFM - 8.0 or absf(p.y) > HALFM - 8.0:
			continue
		if p.distance_to(outpost.C) < 14.0 or _near_passage(p, 6.0):
			continue
		var ok := true
		for o in others:
			if p.distance_to(o) < min_other:
				ok = false
				break
		if not ok:
			continue
		if field.is_solid(p + Vector2(2, 0)) or field.is_solid(p - Vector2(2, 0)) or field.is_solid(p + Vector2(0, 2)) or field.is_solid(p - Vector2(0, 2)):
			continue
		return p
	return null


func _node_kinds_for(res: String) -> Array:
	var out: Array = []
	for k in ea.nodes:
		if String(D.EXP_NODES[k].res) == res:
			out.append(k)
	if out.is_empty():
		for k in D.EXP_NODES:
			if String(D.EXP_NODES[k].res) == res and k != "shard":
				out.append(k)
	return out


func _add_node(kind: String, p: Vector2, ring: int, rng: RandomNumberGenerator) -> Node3D:
	var nd: Dictionary = D.EXP_NODES[kind]
	var amt := rng.randf_range(float(nd.min), float(nd.max))
	if not bool(nd.get("no_factor", false)):
		amt *= factor
	if ring > 0:
		amt *= D.EXP_RICH[ring - 1] if not bool(nd.get("no_factor", false)) else 1.0
	if String(nd.res) in ea.mats and float(nd.max) < 10.0:
		amt *= D.EXP_MAT_BOOST                       # seltene Rohstoffe als Baustoff: ergiebiger
	var n := ResNode.new()
	add_child(n)
	n.setup(kind, p, roundf(amt), ring, rng.randf() * TAU)
	n.cells = field.block_circle_tracked(p, 0.9)
	nodes.append(n)
	return n


## Landezone: fester Zufallswert je Gebiet. Hier liegt immer genug für die offenen Bauplätze plus 30 % Reserve.
func _place_landing_nodes() -> void:
	var need := {}
	for pd in outpost.open_pads():
		var due: Dictionary = pd.due()
		for r in due:
			need[r] = float(need.get(r, 0.0)) + float(due[r])
	var taken: Array = [START, outpost.C]
	var have := {}
	# erst die Pflicht, dann eine Handvoll zusätzlicher Quellen
	for r in need:
		var want := float(need[r]) * D.EXP_RESERVE
		if r == "coins":
			want *= 1.0
		var kinds := _node_kinds_for(String(r))
		if kinds.is_empty():
			continue
		var guard := 0
		while float(have.get(r, 0.0)) < want and guard < 80:
			guard += 1
			var kd: String = kinds[_fixed.randi() % kinds.size()]
			var p = _pick(9.0, 4.0, taken, D.EXP_RING_LAND - 5.0, _fixed)
			if p == null:
				continue
			p = field.center(field.idx(p))
			taken.append(p)
			var n: Node3D = _add_node(kd, p, 0, _fixed)
			have[r] = float(have.get(r, 0.0)) + n.total
	for i in 6:
		var keys: Array = ea.nodes.keys()
		var kd2: String = keys[_fixed.randi() % keys.size()]
		if kd2 == "shard":
			continue
		var p2 = _pick(9.0, 4.0, taken, D.EXP_RING_LAND - 5.0, _fixed)
		if p2 != null:
			p2 = field.center(field.idx(p2))
			taken.append(p2)
			_add_node(kd2, p2, 0, _fixed)


func _place_outer_nodes() -> void:
	var keys: Array = ea.nodes.keys()
	var tot := 0.0
	for k in keys:
		tot += float(ea.nodes[k])
	var taken: Array = [START]
	var shards := 0
	for i in 70:
		var x := _rng.randf() * tot
		var kd: String = keys[0]
		for k in keys:
			x -= float(ea.nodes[k])
			if x <= 0.0:
				kd = k
				break
		if kd == "shard":
			if shards >= int(D.EXP_NODES.shard.max_n):
				continue
			shards += 1
		var p = _pick(D.EXP_RING_LAND + D.EXP_RING_W + 4.0, 7.0, taken)
		if p == null:
			continue
		p = field.center(field.idx(p))
		taken.append(p)
		var ring := 1 if p.length() < D.EXP_RING_MID else 2
		_add_node(kd, p, ring, _rng)
		if _rng.randf() < 0.22:
			group(p + Vector2(3, 3), _rng.randi_range(2, 3), 6.0)
	for i in 6:
		var p2 = _pick(D.EXP_RING_LAND + 12.0, 10.0, taken)
		if p2 != null:
			group(p2, _rng.randi_range(4, 7), 8.0)


func _place_pois() -> void:
	var taken: Array = [START]
	var plan: Array = ["nest", "nest", "bounty", "rescue", "trader", "chest"]
	if _rng.randf() < 0.5:
		plan.append("nest")
	if _rng.randf() < 0.5:
		plan.append("chest")
	if P.vehicle_sel() != "":
		plan.append("race")
	for kd in plan:
		var lo := D.EXP_RING_LAND + 12.0
		var hi := 999.0
		if kd == "bounty" or kd == "chest":
			lo = D.EXP_RING_MID
		elif kd == "trader":
			hi = D.EXP_RING_MID
		var p = _pick(lo, 22.0, taken, hi)
		if p == null:
			p = _pick(D.EXP_RING_LAND + 8.0, 10.0, taken)
		if p == null:
			continue
		taken.append(p)
		var poi := Poi.new()
		add_child(poi)
		poi.setup(self, kd, p, _rng)
		pois.append(poi)
	CompanionFind.place(self)


func ring_mesh(r: float, col: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = r - 0.25
	tor.outer_radius = r
	tor.rings = 40
	tor.ring_segments = 4
	m.mesh = tor
	m.material_override = MK.glow(col)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	return m


# ================================================================= Gegner
func _roll_type() -> int:
	var x := _rng.randf() * _mix_sum
	var mix: Array = adef.enemies
	for t in mix.size():
		x -= float(mix[t])
		if x <= 0.0:
			return t
	return 0


func _dusk_k() -> float:
	return 1.0 + D.EXP_DUSK_POWER * dusk


## Ein Gegner der Gebietsfamilie (role: guard, raid, siege, elite, nest). Nutzt horde.spawn_for_area, wenn vorhanden.
func spawn_enemy(role: String, q: Vector2, extra := 1.0):
	var hm := hp_mult * extra * _dusk_k()
	var dm := (1.0 + 0.1 * int(adef.level)) * _dusk_k()
	var pm := dp_mult * _dusk_k()
	if role == "nest":
		return horde.spawn(D.E_BRUTE, q, 1.0, 1.0, 1.0)
	if horde.has_method("spawn_for_area"):
		var e0 = horde.spawn_for_area(area, q, hm, dm, pm, role)
		if e0 != null:
			return e0
	if role == "elite":
		var e1 = horde.spawn(D.E_BRUTE, q, hm * D.EXP_ELITE_HP, dm, pm)
		e1.sc *= 1.5
		e1.r *= 1.4
		e1.coins = int(30 * factor)
		return e1
	var t := _roll_type()
	if t == D.E_FLYER and _rng.randf() < 0.5:
		t = D.E_SLIME
	if t == D.E_BOSS:
		t = D.E_BRUTE
	return horde.spawn(t, q, hm, dm, pm)


func spawn_boss_at(p: Vector2):
	var hm := hp_mult * 0.35
	var e
	if horde.has_method("spawn_boss"):
		e = horde.spawn_boss(area, p, hm, dp_mult * 0.3)
	if e == null:
		var bd: Dictionary = D.BOSSES[int(adef.boss)]
		e = horde.spawn(D.E_BOSS, p, hm, 1.0, dp_mult * 0.3)
		e.special = bd.special
		e.tint = [Color(1, 1, 1), Color(0.7, 1.1, 0.8), Color(1.2, 0.8, 0.6), Color(0.7, 1.0, 1.2), Color(0.6, 0.9, 0.5), Color(0.9, 1.1, 1.4), Color(1.2, 1.2, 0.6)][int(adef.boss)]
		horde.boss_name = bd.name
	e.home = p
	e.leash = 12.0
	e.coins = int(60 * factor)
	preload("res://src/liveops.gd").on_boss(self, e, p)       # Paket L: Albtraum+ „Doppelte Bosse“
	return e


## Wachende Gruppe an einem Ort (leash) oder angreifende Gruppe (aggro).
func group(c: Vector2, n: int, leash: float, aggro := false) -> void:
	n = int(ceil(n * float(D.DIFFS[diff].count)))
	for i in n:
		if horde.alive >= mini(G.max_alive() - 20, D.EXP_MAX_GUARDS):
			return
		var q := c + Vector2(_rng.randf_range(-leash, leash), _rng.randf_range(-leash, leash)) * 0.6
		if field.is_solid(q):
			continue
		var e = spawn_enemy("guard", q)
		e.home = c
		e.leash = leash
		e.aggro = aggro


## Angriffsgruppe, die dem Richtungsfeld zur Zentrale folgt.
func _raid_group(from: Vector2, n: int, role: String) -> void:
	n = int(ceil(n * float(D.DIFFS[diff].count)))
	for i in n:
		if horde.alive >= mini(G.max_alive() - 5, D.EXP_MAX_ALIVE):
			return
		var q := from + Vector2(_rng.randf_range(-3, 3), _rng.randf_range(-3, 3))
		if field.is_solid(q):
			q = from
		if field.is_solid(q):
			continue
		spawn_enemy(role, q)


## Startpunkt eines Angriffs: innen vor einem Durchgang (solange die Sperren stehen) bzw. davor.
func _passage_spawn(k: int) -> Vector2:
	var a: float = _passages[k % _passages.size()]
	var ax := Vector2(cos(a), sin(a))
	var r := D.EXP_RING_LAND - 4.0 if not _barriers_open() else D.EXP_RING_LAND + D.EXP_RING_W + 6.0
	return field.center(field.idx(ax * r))


func _barriers_open() -> bool:
	return phase == "explore" or phase == "relief"


func _update_goal() -> void:
	var z = outpost.zentrale
	if z != null and z.alive:
		goal_structure = z
		field.set_goal(z.mid)
	else:
		goal_structure = null
		field.set_goal(outpost.C)


# ================================================================= Rucksack, Depot
func unit_weight(r: String) -> float:
	if r == "coins":
		return 0.0
	return float(D.RES_WEIGHT.get(r, 1.0)) / factor * CD.weight_k(r)


func _recalc_weight() -> void:
	weight = 0.0
	for r in loot:
		weight += float(loot[r]) * unit_weight(String(r))


func room_for(r: String) -> float:
	var w := unit_weight(r)
	if w <= 0.0:
		return 1.0e9
	return maxf(0.0, (cap - weight) / w)


## Legt etwas in den Rucksack (begrenzt). Rückgabe: tatsächlich eingepackt.
func add_pack(r: String, amt: float) -> float:
	var take := minf(amt, room_for(r))
	if take <= 0.0:
		return 0.0
	loot[r] = float(loot.get(r, 0.0)) + take
	weight += take * unit_weight(r)
	return take


func field_coins() -> int:
	return int(loot.get("coins", 0.0))


func collect_coin(v: float) -> void:
	add_pack("coins", v * D.EXP_COIN_K * factor * (1.0 + D.EXP_DUSK_LOOT * dusk))


func fill_pack() -> void:
	var mats: Array = ea.mats
	for r in mats:
		var room := room_for(String(r)) / float(mats.size())
		add_pack(String(r), room)
	add_pack("coins", 500.0 * factor)


func _unload() -> void:
	var any := false
	for r in loot.keys():
		if r == "coins":
			continue
		var v := float(loot[r])
		if v >= 1.0:
			depot[r] = float(depot.get(r, 0.0)) + v
			loot.erase(r)
			any = true
			_fly_to(pack.load_point() if pack != null else hero.global_position + Vector3(0, 1.2, 0), Vector3(outpost.depot_pos.x, 0.8, outpost.depot_pos.y), String(r))
	if any:
		loads += 1
		_recalc_weight()
		Sfx.play("depot_drop", -4.0)
		fx.float_text(Vector3(outpost.depot_pos.x, 3.0, outpost.depot_pos.y), "Eingelagert!", D.C_GOLD)
		hero.body.play("pay")
		state_changed.emit()


# ================================================================= Phasen
func _on_built(key: String) -> void:
	var pd: Dictionary = outpost.local_def(key)
	P.add_hero_xp(hero.key, D.EXP_XP.pad)
	_push_out_of_buildings()
	if key == "zentrale":
		_update_goal()
		if phase == "land":
			phase = "build"
			raid_t = D.EXP_RAID_EVERY
			P.toast.emit("Die Zentrale steht – alle Bauplätze sind frei. Achtung, Angriffe!")
	if phase == "build" and outpost.mandatory_done():
		_start_siege()
	# Ausbau: alle Plätze der nächsten Stufe bezahlt?
	var lv := P.outpost_level(String(adef.key))
	if lv >= 1 and int(pd.get("level", 1)) == lv + 1 and outpost.upgrade_done(lv + 1) and not preload("res://src/liveops.gd").outpost_gate(self, lv + 1, key):     # Paket L: Stufe 4/5 erst nach dem Gebietsboss
		var nl := P.outpost_set_level(String(adef.key), lv + 1)
		Sfx.play("outpost_level", -2.0)
		fx.confetti(Vector3(outpost.C.x, 2.0, outpost.C.y), 8)
		P.toast.emit("Außenbasis Stufe %d!" % nl)
		if nl < D.OUTPOST_MAX_LEVEL:
			for pd2 in D.OUTPOST_PADS:
				if int(pd2.level) == nl + 1:
					outpost._make_pad(pd2)
			outpost.update_locks()
	state_changed.emit()


## Steht der Held nach einem Bau in einer Wand, wird er zur Mitte hin herausgeschoben.
func _push_out_of_buildings() -> void:
	var pp: Vector2 = hero.pos2()
	if hero.mounted or not hero._blocked(field, pp, 0.46):
		return
	for r in [0.6, 1.2, 2.0, 3.0, 4.5, 6.0]:
		var best = null
		var bd := 1.0e9
		for i in 16:
			var q: Vector2 = pp + Vector2.from_angle(i * TAU / 16.0) * r
			if hero._blocked(field, q, 0.5):
				continue
			var d := q.distance_to(outpost.C)
			if d < bd:
				bd = d
				best = q
		if best != null:
			hero.global_position = Vector3(best.x, 0, best.y)
			return


func _start_siege() -> void:
	if phase == "siege":
		return
	phase = "siege"
	siege_t = 0.0
	_siege_wave_t = 0.0
	elite = null
	Sfx.play("siege_horn", -1.0)
	Music.set_mood("boss")
	P.toast.emit("Großangriff! Halte die Zentrale %d Sekunden." % int(D.EXP_SIEGE_TIME))
	state_changed.emit()


func _tick_siege(dt: float) -> void:
	siege_t += dt
	_siege_wave_t -= dt
	if siege_t < D.EXP_SIEGE_TIME and _siege_wave_t <= 0.0:
		_siege_wave_t = D.EXP_SIEGE_EVERY
		var n := 3 + int(siege_t / 20.0) + int(area / 3)
		_raid_group(_passage_spawn(0), n, "siege")
		_raid_group(_passage_spawn(1), n, "siege")
	if siege_t >= D.EXP_SIEGE_TIME and elite == null:
		elite = spawn_enemy("elite", _passage_spawn(2))
		Sfx.play("elite_arrive", -2.0)
		P.toast.emit("Ein Elitegegner greift an!")
	if elite != null and elite.st == 2:
		_siege_won()


func _siege_won() -> void:
	var ak := String(adef.key)
	P.outpost_set_level(ak, 1)
	P.add_hero_xp(hero.key, D.EXP_XP.outpost)
	phase = "explore"
	explore_t = 0.0
	Music.set_mood("battle")
	Sfx.play("outpost_done", -1.0)
	fx.confetti(Vector3(outpost.C.x, 2.0, outpost.C.y), 12)
	P.toast.emit("Die Außenbasis steht! Die Sperren lösen sich auf.")
	_open_barriers()
	for pd in D.OUTPOST_PADS:
		if int(pd.level) == 2:
			outpost._make_pad(pd)
	outpost.update_locks()
	state_changed.emit()


func _open_barriers() -> void:
	if not _outer_solid.is_empty():
		field.solid = _outer_solid
		_outer_solid = PackedByteArray()
	for b in barriers:
		for ci in b.cells:
			field.solid[ci] = 0
		if b.n != null:
			var n: Node3D = b.n
			fx.explosion(n.global_position + Vector3(0, 1.5, 0), 4.0, Color(0.9, 0.85, 0.6))
			var tw := n.create_tween()
			tw.tween_property(n, "scale", Vector3(1.0, 0.02, 1.0), 1.2)
			tw.tween_callback(func(): n.visible = false)
			b.n = null
	# einmalige volle Neuberechnung (rund 90 ms) hier statt im Gegner-Takt; die Kamera zeigt gerade die Durchgänge
	field.rebuild()
	field.dirty = false
	_nav_goal = Vector2(9999, 9999)
	Sfx.play("barrier_dissolve", -2.0)
	if G.autotest == "" or G.shots_dir != "":
		_show_t = 0.0
		_show_i = 0


## Für Tests: Wie viele Durchgänge führen vom Start aus der Landezone? (-1 nicht möglich = 0)
func exits_from_start() -> int:
	var seen := {}
	var si: int = field.idx(START)
	var stack: Array = [si]
	seen[si] = true
	while stack.size() > 0:
		var ci: int = stack.pop_back()
		var cx := ci % N
		var cz := int(ci / N)
		for o in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var nx: int = cx + o[0]
			var nz: int = cz + o[1]
			if nx < 0 or nz < 0 or nx >= N or nz >= N:
				continue
			var ni := nx + nz * N
			if not seen.has(ni) and field.solid[ni] == 0:
				seen[ni] = true
				stack.append(ni)
	var n := 0
	for a in _passages:
		var q := Vector2(cos(a), sin(a)) * (D.EXP_RING_LAND + D.EXP_RING_W + 3.0)
		if seen.has(field.idx(q)):
			n += 1
	return n


## Wegsuche vom Start zum Kartenrand: gibt es irgendeine Zelle außerhalb des Sperrrings, die erreichbar ist?
func path_to_edge() -> bool:
	var f := Field.new(Vector2(-HALFM, -HALFM), N, N, 2.0)
	f.solid = field.solid.duplicate()
	f.set_goal(START)
	f.rebuild()
	for i in N * N:
		var c: Vector2 = f.center(i)
		if c.length() > D.EXP_RING_LAND + D.EXP_RING_W + 2.0 and f.dist[i] < Field.BIG * 0.5:
			return true
	return false


# ================================================================= Ende
func can_respawn() -> bool:
	return respawns_left >= 0 and _dead_t < 0.0


func respawn_point() -> Vector2:
	var z = outpost.zentrale
	if z != null and z.alive:
		return z.mid + outpost.s * 4.5
	return START


func _on_hero_died() -> void:
	# der Rucksack verliert die Hälfte (das Depot nicht; Begleiter mit „Sichere Ladung“ schützen mehr)
	var keep := CD.death_keep()
	for r in loot.keys():
		loot[r] = float(loot[r]) * keep
	_recalc_weight()
	mining = null
	respawns_left -= 1
	if respawns_left < 0:
		_dead_t = 1.6
		P.toast.emit("Dein Held ist erschöpft – nur das Depot und der halbe Rucksack kommen heim.")
	else:
		hero._respawn = D.EXP_RESPAWN_TIME
		P.toast.emit("Wiedereinstieg in %d s (noch %d×). Der Rucksack hat %s verloren." % [int(D.EXP_RESPAWN_TIME), respawns_left, "die Hälfte" if keep <= 0.5 else "%d %%" % int(round((1.0 - keep) * 100.0))])


func on_structure_destroyed(s) -> void:
	if s == outpost.zentrale:
		outpost.zentrale_fallen()
		_update_goal()
		P.toast.emit("Die Zentrale ist gefallen! In %d s kann sie wieder aufgebaut werden." % int(D.EXP_RUBBLE_TIME))
		Sfx.play("zentrale_down", -2.0)


func can_go_home() -> bool:
	if ended or not hero.alive or phase != "explore":
		return false
	var pp: Vector2 = hero.pos2()
	var z = outpost.zentrale
	if z != null and pp.distance_to(z.mid) < D.EXP_HOME_RADIUS:
		return true
	return hero.mounted and pp.distance_to(outpost.C) < 14.0


func go_home() -> void:
	if can_go_home():
		Sfx.play("extract_success", -5.0)
		_finish(true, "home")


func abort() -> void:
	_finish(false, "abort")


func _finish(success: bool, how := "") -> void:
	if ended:
		return
	ended = true
	running = false
	var home := depot.duplicate()
	if how != "abort":
		for r in loot:
			home[r] = float(home.get(r, 0.0)) + float(loot[r])
	for r in home.keys():
		if r != "coins":
			home[r] = float(home[r]) * loot_bonus
	var ak := String(adef.key)
	if success and mission == "befreiung":
		P.outpost_relieve(ak)
	result = P.expedition_end(area, diff, hero.key, success, home, {"bounty": bounty_done, "rescued": rescued, "race_time": race_time,
		"chests": chests_found, "kills": horde.kills})
	result["kills"] = horde.kills
	result["mission"] = mission
	result["area"] = area
	result["time"] = race_time
	result["how"] = how
	result["phase"] = phase
	result["loads"] = loads
	result["win"] = success
	Sfx.play("win" if success else "lose", -2.0)
	if success and hero.alive:
		hero.body.cheer(3.0)
	battle_ended.emit()
	state_changed.emit()


## Nebenaufgabe erledigt (poi.gd).
func poi_done(poi, text: String) -> void:
	match poi.kind:
		"nest":
			chests_found += 1
			P.add_hero_xp(hero.key, D.EXP_XP.nest)
			if _rng.randf() < DW.EGG_NEST_P and WS.eggs().size() < DW.EGG_MAX:      # Paket Welt: im Nest lag ein Ei
				WS.add_egg("nest", "", _rng)
				Sfx.play("egg_found", -3.0)
				text += " Und ein Begleiter-Ei!"
		"bounty":
			bounty_done = true
			P.add_hero_xp(hero.key, D.EXP_XP.bounty)
		"rescue":
			rescued = poi.who != ""
			P.add_hero_xp(hero.key, D.EXP_XP.rescue)
		"race":
			P.add_hero_xp(hero.key, D.EXP_XP.race)
		"chest":
			P.add_hero_xp(hero.key, D.EXP_XP.chest)
	P.toast.emit(text)
	state_changed.emit()


# ================================================================= Anzeige
func phase_name() -> String:
	return String(D.EXP_PHASE_NAME.get(phase, phase))


func objective_text() -> String:
	match phase:
		"land":
			if outpost.pads.has("zentrale"):
				return "Sammle Münzen und Rohstoffe, dann stell dich auf den Bauplatz der Zentrale"
			return "Sammle Münzen und Rohstoffe"
		"build":
			if raid_warn > 0.0:
				return "Angriff in %d s!" % int(ceil(raid_warn))
			var open := 0
			for pd in D.OUTPOST_PADS:
				if int(pd.level) == 1 and bool(pd.get("must", false)) and not outpost.built_ok(String(pd.key)):
					open += 1
			return "Baue die Außenbasis: noch %d Pflichtplätze" % open
		"siege":
			if siege_t < D.EXP_SIEGE_TIME:
				return "Großangriff! Halte durch: %s" % _mmss(D.EXP_SIEGE_TIME - siege_t)
			return "Besiege den Elitegegner!"
		"relief":
			return "Befreiung: Welle %d von %d – %s" % [maxi(relief_wave, 1), D.OUTPOST_SIEGE_WAVES, _mmss(D.OUTPOST_SIEGE_TIME - _relief_t)]
		"explore":
			var t := "Erkunde das Gebiet · Depot: %d Ladungen" % loads
			if dusk > 0:
				t += " · Dämmerung %d" % dusk
			elif explore_t > D.EXP_DUSK_AFTER - 120.0:
				t += " · Dämmerung in %s" % _mmss(D.EXP_DUSK_AFTER - explore_t)
			return t
	return ""


func _mmss(t: float) -> String:
	var s := int(maxf(t, 0.0))
	return "%d:%02d" % [int(s / 60), s % 60]


## Nebenaufgaben für die Liste links.
func side_quests() -> Array:
	var out: Array = []
	if phase == "explore":
		for p in pois:
			out.append([p.status_text(), p.done])
	else:
		for p in pois:
			if p.kind == "pet":
				out.append([p.status_text(), p.done])
	if welt != null:
		out.append_array(welt.quest_lines())
	return out


## Gebietseigene Quelle, für die das Werkzeug fehlt? (Paket Welt)
func node_locked(n) -> bool:
	return welt != null and welt.tool_missing(n) != ""


## Pfeil am Bildrand: [Weltpunkt, Farbe] oder [].
func hint_arrow() -> Array:
	if raid_warn > 0.0:
		return [raid_from, Color("FB3D54")]
	var pp: Vector2 = hero.pos2()
	var pad = _pad_under(pp)
	if pad != null:
		var due: Dictionary = pad.due()
		for r in D.RES:
			if due.has(r) and float(loot.get(r, 0.0)) < 1.0:
				var n = _nearest_node(r, pp)
				if n != null:
					return [n.p, D.RES_COLOR.get(r, D.C_GOLD)]
	return []


func _pad_under(pp: Vector2):
	for k in outpost.pads:
		var p = outpost.pads[k]
		if not p.done and p.on_pad(pp):
			return p
	return null


func _nearest_node(r: String, pp: Vector2):
	var best = null
	var bd := 1.0e9
	for n in nodes:
		if n.gone or n.res != r or _bot_bad.has(n) or node_locked(n):
			continue
		if not _barriers_open() and n.ring > 0:
			continue
		var d: float = n.p.distance_squared_to(pp)
		if d < bd:
			bd = d
			best = n
	return best


## Punkte für die Übersichtskarte: [Position, Art, (Farbe)]
func map_points() -> Array:
	var out: Array = [[outpost.C, "base"]]
	for n in nodes:
		if not n.gone and _seen(n.p):
			out.append([n.p, "pile", D.RES_COLOR.get(n.res, D.C_GOLD)])
	for k in outpost.pads:
		out.append([outpost.pads[k].center, "pad"])
	for b in barriers:
		if b.n != null:
			out.append([b.p, "barrier"])
	for p in pois:
		if not p.done and (phase == "explore" or p.kind == "pet") and (_seen(p.p) or p.kind == "bounty"):
			out.append([p.target(), "goal"])
	if raid_warn > 0.0:
		out.append([raid_from, "raid"])
	var vp = hero.vehicle_pos()
	if vp != null:
		out.append([Vector2(vp.x, vp.z), "vehicle"])
	if welt != null:
		welt.map_points(out)
	return out


func _seen(p: Vector2) -> bool:
	var x := clampi(int((p.x + HALFM) / D.EXP_FOG_CELL), 0, fog_n - 1)
	var z := clampi(int((p.y + HALFM) / D.EXP_FOG_CELL), 0, fog_n - 1)
	return fog[x + z * fog_n] == 1


func _reveal(pp: Vector2) -> void:
	var r: float = D.EXP_FOG_RADIUS * CD.scout_k() * (welt.reveal_k() if welt != null else 1.0)
	var x0 := clampi(int((pp.x - r + HALFM) / D.EXP_FOG_CELL), 0, fog_n - 1)
	var x1 := clampi(int((pp.x + r + HALFM) / D.EXP_FOG_CELL), 0, fog_n - 1)
	var z0 := clampi(int((pp.y - r + HALFM) / D.EXP_FOG_CELL), 0, fog_n - 1)
	var z1 := clampi(int((pp.y + r + HALFM) / D.EXP_FOG_CELL), 0, fog_n - 1)
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var c := Vector2((x + 0.5) * D.EXP_FOG_CELL - HALFM, (z + 0.5) * D.EXP_FOG_CELL - HALFM)
			if c.distance_to(pp) < r + D.EXP_FOG_CELL * 0.5:
				fog[x + z * fog_n] = 1


# ================================================================= fliegende Stücke
func _chunk() -> MeshInstance3D:
	var m: MeshInstance3D
	if _chunk_pool.size() > 0:
		m = _chunk_pool.pop_back()
	else:
		m = MeshInstance3D.new()
		m.mesh = _chunk_mesh
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
	m.visible = true
	return m


func _spawn_chunks(n, amt: float) -> void:
	var parts := 3
	var col: Color = D.RES_COLOR.get(n.res, Color.WHITE)
	for i in parts:
		var m := _chunk()
		m.material_override = MK.glow(col)
		var a := Vector3(n.p.x, 1.0, n.p.y)
		var hop := a + Vector3(_rng.randf_range(-1.6, 1.6), _rng.randf_range(1.0, 2.0), _rng.randf_range(-1.6, 1.6))
		_chunks.append({"n": m, "a": a, "h": hop, "t": 0.0, "res": n.res, "amt": amt / parts, "home": true})


func _fly_to(a: Vector3, b: Vector3, r: String) -> void:
	var m := _chunk()
	m.material_override = MK.glow(D.RES_COLOR.get(r, Color.WHITE))
	_chunks.append({"n": m, "a": a, "h": (a + b) * 0.5 + Vector3(0, 1.5, 0), "b": b, "t": 0.0, "res": r, "amt": 0.0, "home": false})


func _tick_chunks(dt: float) -> void:
	var hp: Vector3 = pack.load_point() if pack != null else hero.global_position + Vector3(0, 1.2, 0)
	for i in range(_chunks.size() - 1, -1, -1):
		var c: Dictionary = _chunks[i]
		c.t = float(c.t) + dt
		var m: MeshInstance3D = c.n
		var pos: Vector3
		if c.home:
			if c.t < 0.3:
				pos = (c.a as Vector3).lerp(c.h, c.t / 0.3)
			else:
				var k := minf((c.t - 0.3) / 0.35, 1.0)
				pos = (c.h as Vector3).lerp(hp, k * k)
		else:
			var k2 := minf(c.t / 0.35, 1.0)
			pos = (c.a as Vector3).lerp(c.h, k2).lerp((c.h as Vector3).lerp(c.b, k2), k2)
		m.global_position = pos
		m.rotation = Vector3(c.t * 7.0, c.t * 5.0, 0)
		var dur := 0.65 if c.home else 0.35
		if c.t >= dur:
			m.visible = false
			_chunk_pool.append(m)
			_chunks.remove_at(i)
			if c.home:
				var got := add_pack(String(c.res), float(c.amt))
				if got < float(c.amt) * 0.99 and _full_msg_t <= 0.0:
					_full_msg_t = 2.0
					fx.float_text(hero.global_position + Vector3(0, 3, 0), "Rucksack voll!", Color("FB3D54"))
					Sfx.play("backpack_full", -6.0, 1.0, 1.5)


# ================================================================= Schleife
func _physics_process(dt: float) -> void:
	tick_common(dt)
	if ended:
		return
	var pp: Vector2 = hero.pos2()
	_tick_chunks(dt)
	_full_msg_t -= dt
	_lock_msg_t -= dt
	if _dead_t >= 0.0:
		_dead_t -= dt
		if _dead_t <= 0.0:
			_finish(false, "fell")
		return
	if not hero.alive:
		return
	_fog_t -= dt
	if _fog_t <= 0.0:
		_fog_t = 0.5
		_reveal(pp)
		if hero.speed_now < 0.2:
			_push_out_of_buildings()
	_tick_mining(dt, pp)
	if pack == null:
		pack = Backpack.new()
		add_child(pack)
		pack.setup(self)
	pack.tick(dt, pp)
	_tick_pads(dt, pp)
	_tick_base(dt, pp)
	match phase:
		"build":
			_tick_raids(dt)
		"siege":
			_tick_siege(dt)
		"relief":
			_tick_relief(dt)
		"explore":
			_tick_explore(dt, pp)
	welt.tick(dt, pp)
	if vulkan != null:
		vulkan.tick(dt, pp)
	if phase != "explore":           # Paket Welt: gefangene Begleiter in der Landezone gibt es in jeder Phase
		for p in pois:
			if p.kind == "pet" and not p.done:
				p.tick(dt, pp)
	if _show_t >= 0.0:
		_show_t += dt
		if _show_i < barriers.size():
			var bp: Vector2 = barriers[_show_i].p
			cam.override_target = Vector3(bp.x, 0, bp.y)
			if _show_t > 1.3:
				_show_t = 0.0
				_show_i += 1
		else:
			cam.override_target = null
			_show_t = -1.0
	if G.autotest != "":
		_bot_skill_t -= dt
		if _bot_skill_t <= 0.0:
			_bot_skill_t = 1.0
			for i in 4:
				if hero.skills.ready(i) and horde.nearest(pp, 12.0) != null:
					hero.skills.use(i)


## Abbauen: kurz (0,3 s, Ladekreis) neben einer Quelle stehen, dann Schläge alle 0,42 s (Heldenstufe macht schneller).
func _tick_mining(dt: float, pp: Vector2) -> void:
	if hero.mounted or hero.speed_now > D.EXP_MINE_MOVE:
		_still = 0.0
		if mining != null:
			mining = null
			hero.body.stop_clip()
		if pack != null:
			pack.show_ring(null if hero.mounted else _mine_target(pp), 0.0, true)
		return
	_still += dt
	if mining == null:
		var best = _mine_target(pp)
		if pack != null:
			pack.show_ring(best, clampf(_still / D.EXP_MINE_IDLE, 0.0, 1.0), false)
		if best == null and _still >= D.EXP_MINE_IDLE:
			var lk = _mine_target(pp, true)     # gebietseigene Quelle ohne Werkzeug: Hinweis
			if lk != null:
				welt.tool_hint(lk)
		if best == null or _still < D.EXP_MINE_IDLE:
			return
		if room_for(best.res) < 1.0:
			if _full_msg_t <= 0.0:
				_full_msg_t = 2.5
				fx.float_text(hero.global_position + Vector3(0, 3, 0), "Rucksack voll! Wirf etwas ab", Color("FB3D54"))
				Sfx.play("backpack_full", -6.0, 1.0, 1.5)
			return
		mining = best
		_hit_t = 0.05
		var to: Vector2 = best.p - pp
		hero.rotation.y = atan2(to.x, to.y)
	if pack != null:
		pack.show_ring(mining, 1.0, false)
	if mining.gone:
		mining = null
		hero.body.stop_clip()
		return
	_hit_t -= dt
	if _hit_t <= 0.0:
		_hit_t = D.EXP_HIT_TIME / (1.0 + D.EXP_HIT_LEVEL * (hero.level - 1)) / CD.mine_k(String(mining.res))
		hero.body.play(String(mining.def.clip))
		var amt: float = mining.hit()
		amt *= 1.0 + float(hero.m.get("carry", 0.0)) * 0.5
		amt *= 1.0 + D.EXP_DUSK_LOOT * dusk
		amt *= welt.yield_k(String(mining.res))
		welt.on_hit(mining)
		_spawn_chunks(mining, amt)
		var rare := String(mining.def.get("rare", ""))
		if rare != "" and _rng.randf() < float(mining.def.rare_p) / float(mining.hits) * CD.luck():
			_chunks.append({"n": _chunk(), "a": Vector3(mining.p.x, 1.0, mining.p.y), "h": Vector3(mining.p.x, 2.6, mining.p.y), "t": 0.0, "res": rare, "amt": 1.0, "home": true})
			fx.float_text(Vector3(mining.p.x, 2.6, mining.p.y), "+1 %s" % D.RES_NAME[rare], D.C_GOLD)
		Sfx.play_at(String(mining.def.get("snd", "hit_" + String(mining.def.clip))), Vector3(mining.p.x, 0.5, mining.p.y), -6.0, 1.0, 0.12)
		fx.puff(Vector3(mining.p.x, 0.9, mining.p.y), D.RES_COLOR.get(mining.res, Color.WHITE).lightened(0.2), 5, 1.0)


## Nächste Quelle in Reichweite (oder null). locked: nur Quellen, für die das Werkzeug fehlt.
func _mine_target(pp: Vector2, locked := false):
	var best = null
	var bd := 1.0e9
	for n in nodes:
		if n.gone or node_locked(n) != locked:
			continue
		var d: float = n.p.distance_to(pp)
		if d < n.reach() and d < bd:
			bd = d
			best = n
	return best


## Bezahlen: Steht der Held zu Fuß auf einem Bauplatz, fließt alle 0,08 s eine Einheit herüber.
func _tick_pads(dt: float, pp: Vector2) -> void:
	var pad = _pad_under(pp)
	if pad == null or hero.mounted:
		_pay_t = 0.0
		return
	if pad.locked:
		if _lock_msg_t <= 0.0:
			_lock_msg_t = 3.0
			P.toast.emit("%s: %s" % [pad.def.name, outpost.pad_block(pad.key)])
		return
	_pay_t += dt
	var ak := String(adef.key)
	var unit := maxf(1.0, ceilf(factor))
	var paid_any := false
	while _pay_t >= D.EXP_PAY_TICK:
		_pay_t -= D.EXP_PAY_TICK
		var due: Dictionary = pad.due()
		var r := ""
		for rr in D.RES:
			if due.has(rr) and float(loot.get(rr, 0.0)) >= 0.999:
				r = rr
				break
		if r == "":
			break
		var n := minf(minf(unit, float(due[r])), float(loot[r]))
		loot[r] = float(loot[r]) - n
		if float(loot[r]) < 0.001:
			loot.erase(r)
		if pad.rebuild:
			pad.paid[r] = float(pad.paid.get(r, 0.0)) + n
		else:
			P.outpost_pay(ak, pad.key, r, n)
		paid_any = true
		_fly_to(hero.global_position + Vector3(0, 1.4, 0), Vector3(pad.center.x, 0.6, pad.center.y), r)
		if pad.due().is_empty():
			break
	if paid_any:
		_recalc_weight()
		Sfx.play("pad_pay", -12.0, 1.0 + pad.progress() * 0.4, 0.05)
		pad.refresh(loot)
		if pad.due().is_empty():
			fx.confetti(Vector3(pad.center.x, 1.5, pad.center.y), 4)
			Sfx.play("pad_build", -3.0)
			hero.body.play("pay")
			outpost.complete_pad(pad.key)
	elif _full_msg_t <= 0.0:
		_full_msg_t = 2.5
		pad.refresh(loot)


## Außenbasis: Depot ausleeren, Lagerfeuer heilt, Parkplatz repariert, Heilung außerhalb des Kampfes.
func _tick_base(dt: float, pp: Vector2) -> void:
	_heal_t -= dt
	if _heal_t > 0.0:
		return
	_heal_t = 0.25
	var k := 0.25
	var dp: Node3D = outpost.nodes.get("depot")
	_depot_ring.visible = dp != null
	if dp != null:
		_depot_ring.position = Vector3(outpost.depot_pos.x, 0.12, outpost.depot_pos.y)
		if pp.distance_to(outpost.depot_pos) < 1.8 and not hero.mounted:
			_unload()
	var fire = outpost.nodes.get("feuer")
	if fire != null and fire.alive and pp.distance_to(fire.mid) < D.EXP_FIRE_RADIUS:
		hero.heal(hero.max_hp * D.EXP_FIRE_HEAL * k)
	var park = outpost.nodes.get("park")
	var vp = hero.vehicle_pos()
	if park != null and hero.veh_node != null:
		var vq: Vector2 = pp if hero.mounted else (Vector2(vp.x, vp.z) if vp != null else Vector2(9999, 9999))
		if vq.distance_to(park.mid) < 3.0 and hero.veh_hp < hero.veh_max:
			hero.veh_hp = minf(hero.veh_max, hero.veh_hp + hero.veh_max * D.EXP_PARK_REPAIR * k)
	var ooc := P.outpost_bonus("heal_ooc")
	if ooc > 0.0 and hero._since_hit > 5.0 and horde.nearest(pp, 14.0) == null:
		hero.heal(ooc * k)
	var z = outpost.zentrale
	_home_ring.visible = phase == "explore" and z != null and z.alive
	if _home_ring.visible:
		_home_ring.position = Vector3(z.mid.x + outpost.s.x * 4.5, 0.12, z.mid.y + outpost.s.y * 4.5)


## Störangriffe alle 50 s aus der Richtung eines Durchgangs (5 s vorher Hornsignal und roter Pfeil).
func _tick_raids(dt: float) -> void:
	if raid_warn > 0.0:
		raid_warn -= dt
		if raid_warn <= 0.0:
			raid_warn = -1.0
			var built := 0
			for pd in D.OUTPOST_PADS:
				if outpost.built_ok(String(pd.key)):
					built += 1
			_raid_group(raid_from, D.EXP_RAID_BASE + D.EXP_RAID_PER_PAD * built, "raid")
		return
	raid_t -= dt
	if raid_t <= 0.0:
		raid_t = D.EXP_RAID_EVERY
		raid_warn = D.EXP_RAID_WARN
		raid_from = _passage_spawn(_rng.randi() % _passages.size())
		Sfx.play("raid_horn", -2.0)
		P.toast.emit("Ein Angriff naht!")


## Befreiung einer belagerten Außenbasis: drei Wellen in vier Minuten.
func _tick_relief(dt: float) -> void:
	_relief_t += dt
	var every := D.OUTPOST_SIEGE_TIME / float(D.OUTPOST_SIEGE_WAVES + 0.5)
	if relief_wave < D.OUTPOST_SIEGE_WAVES and _relief_t >= relief_wave * every + 3.0:
		relief_wave += 1
		Sfx.play("raid_horn", -2.0)
		for k in 2:
			_raid_group(_passage_spawn(relief_wave + k), 8 + 3 * relief_wave, "siege")
		if relief_wave == D.OUTPOST_SIEGE_WAVES:
			elite = spawn_enemy("elite", _passage_spawn(relief_wave + 2))
	if _relief_t >= D.OUTPOST_SIEGE_TIME and (elite == null or elite.st == 2):
		P.toast.emit("Die Außenbasis ist befreit – ihr Vorteil wirkt wieder!")
		_finish(true, "relief")


func _tick_explore(dt: float, pp: Vector2) -> void:
	explore_t += dt
	for p in pois:
		if not p.done or p.kind == "rescue":
			p.tick(dt, pp)
	# Dämmerung
	if explore_t > D.EXP_DUSK_AFTER:
		var dk := 1 + int((explore_t - D.EXP_DUSK_AFTER) / D.EXP_DUSK_STEP)
		if dk != dusk:
			dusk = dk
			Sfx.play("dusk_bell", -4.0)
			P.toast.emit("Es wird dunkel: Gegner +%d %%, Beute +%d %%" % [int(D.EXP_DUSK_POWER * 100 * dusk), int(D.EXP_DUSK_LOOT * 100 * dusk)])
	# Licht der Dämmerung: Tageslauf in exp_world.gd (Abend, Nacht)
	# streunende Gruppen außerhalb der Landezone
	_roam_t -= dt
	if _roam_t <= 0.0:
		_roam_t = 25.0 if dusk == 0 else 15.0
		if horde.alive < G.max_alive() / 2:
			var q = _pick(D.EXP_RING_LAND + 8.0, 0.0, [], 999.0)
			if q != null and q.distance_to(pp) > 30.0:
				group(q, _rng.randi_range(4, 7), 9.0, dusk > 0)


# ================================================================= Admin
## Bezahlt einen Bauplatz vollständig (ohne Rucksack).
func admin_pay(key: String) -> void:
	if not outpost.pads.has(key):
		return
	var pad = outpost.pads[key]
	var due: Dictionary = pad.due()
	for r in due:
		if pad.rebuild:
			pad.paid[r] = float(pad.paid.get(r, 0.0)) + float(due[r])
		else:
			P.outpost_pay(String(adef.key), key, String(r), float(due[r]))
	outpost.complete_pad(key)


## Admin/Test: Gebiets-Ereignis sofort starten (oder beenden, wenn eines läuft).
func admin_event() -> void:
	if welt.event_active():
		welt.end_event()
	else:
		welt.start_event()


func admin_skip_phase() -> void:
	match phase:
		"land":
			admin_pay("zentrale")
		"build":
			for key in BOT_ORDER:
				var pd: Dictionary = outpost.local_def(key)
				if int(pd.get("level", 9)) == 1 and bool(pd.get("must", false)):
					admin_pay(key)
		"siege":
			_siege_won()
		"relief":
			_relief_t = D.OUTPOST_SIEGE_TIME
			elite = null


func admin_outpost_done() -> void:
	if P.outpost_level(String(adef.key)) < 1:
		while phase != "explore" and not ended:
			admin_skip_phase()
		return
	var target := P.outpost_level(String(adef.key)) + 1
	for key in BOT_ORDER:
		var pd: Dictionary = outpost.local_def(key)
		if int(pd.get("level", 9)) == target:
			admin_pay(key)


# ================================================================= Testbetrieb
## Bot: Quellen abbauen, Bauplätze in Reihenfolge bezahlen, Großangriff an der Zentrale, dann zwei Ladungen ins Depot, heimkehren.
const BOT_ORDER := ["zentrale", "t1", "depot", "t2", "wall_n", "wall_o", "wall_s", "wall_w", "tor", "special",
	"t3", "special_2", "special_3", "walls_3", "special_4", "t4", "special_5", "depot_5"]


func bot_goal():
	var pp: Vector2 = hero.pos2()
	_bot_t -= get_physics_process_delta_time()
	if _bot_t <= 0.0 or _bot_target == null:
		_bot_t = 0.4
		_bot_target = _bot_decide(pp)
		# steckt der Bot fest (lange keine Bewegung, keine Arbeit), weicht er aus und meidet das Ziel
		if mining == null and phase != "siege" and phase != "relief" and _bot_target.distance_to(pp) > 1.0:
			var dt2: float = _bot_target.distance_to(pp)
			if _bot_target.distance_to(_bot_last) > 1.5 or dt2 < _bot_best - 1.0:
				_bot_stuck_t = 0.0
				_bot_last = _bot_target
				_bot_best = dt2
			else:
				_bot_stuck_t += 0.4
			if _bot_stuck_t > 15.0:
				_bot_stuck_t = 0.0
				if _bot_pick != null:
					_bot_bad[_bot_pick] = true
					_bot_pick = null
				_bot_detour_t = 4.0
				_bot_best = 1.0e9
				_bot_detour = pp + Vector2.from_angle(_rng.randf() * TAU) * 8.0
		if _bot_detour_t > 0.0:
			_bot_detour_t -= 0.4
			_bot_target = _bot_detour
		if G.arg("botdebug") != "" and int(time * 2.5) % 10 == 0:
			print("BOT pp=%s target=%s mining=%s still=%.1f speed=%.1f pads=%s" % [pp.round(), str(_bot_target), mining != null, _still, hero.speed_now, str(outpost.pads.keys())])
	var target = _bot_target
	if target == null:
		return null
	# wie ein Mensch: angekündigten Einschlägen (rote Ringe, Bodenmarker) und brennendem Boden ausweichen
	var dg: Vector2 = horde.ai.dodge(pp) if horde.ai != null else Vector2.ZERO
	for e in horde.in_radius(pp, 11.5):
		# große Brecher (Wächter, Yeti), die kämpfen: nie in Hammer- oder Wurfreichweite kommen (ruhende Wachen nicht)
		if e.r > 0.8 and not e.stat and (e.chase or e.st == 1 or e.leash <= 0.0):
			var keep: float = 7.5 + e.r if e.rng <= 0.0 else e.rng + 1.5
			var aw: Vector2 = pp - e.p
			if aw.length() < keep:
				dg += aw.normalized() * maxf(0.5, keep - aw.length()) * 2.0
	if dg != Vector2.ZERO:
		var q0 = _bot_escape(pp, dg, clampf(dg.length() + 1.5, 3.0, 5.0))
		if q0 != null:
			return q0
	# wie ein Mensch: Abstand halten, wenn es eng wird
	var near: Array = horde.in_radius(pp, 5.0 if hero.hp > hero.max_hp * 0.5 else 8.0)
	var crowd := 0
	var cen := Vector2.ZERO
	for e in near:
		if not e.stat:
			crowd += 4 if e.r > 0.8 else 1         # große Brecher (Wächter, Yeti) nie im Nahkampf stehen lassen
			cen += e.p
	if hero.hp < hero.max_hp * 0.35 and near.size() > 0:
		crowd = maxi(crowd, 4)                 # wenig Leben: jedem Gegner ausweichen
	if crowd >= 4 and near.size() > 0 and (mining == null or hero.hp < hero.max_hp * 0.35):
		cen /= near.size()
		var q = _bot_escape(pp, pp - cen, 4.0)       # in der Ecke: seitlich heraus statt stehen zu bleiben
		if q != null:
			return q
	if pp.distance_to(target) < 0.7:
		return target
	if _nav == null:
		_nav = Field.new(Vector2(-HALFM, -HALFM), N, N, 2.0)
	if target.distance_to(_nav_goal) > 1.5 or field.rebuilds != _nav_rb:
		_nav_goal = target
		_nav_rb = field.rebuilds
		_nav.solid = field.solid.duplicate()
		for ci in field.cells:
			var s = field.cells[ci]
			if s.alive and s.blocks_player:
				_nav.solid[ci] = 1
		_nav.solid[field.idx(target)] = 0
		_nav.set_goal(target)
		_nav.rebuild()
	if pp.distance_to(target) < 2.2:
		return target
	return pp + _nav.dir_at(pp) * 3.0


## Ausweichpunkt in Richtung dir (bei Mauer/Fels schrittweise seitlich gedreht); null, wenn alles zu ist.
func _bot_escape(pp: Vector2, dir: Vector2, dist: float):
	var d := dir.normalized() if dir.length_squared() > 0.0001 else Vector2.RIGHT
	for k in 7:
		var a := ceilf(k / 2.0) * 0.55 * (1.0 if k % 2 == 1 else -1.0)
		var q := pp + d.rotated(a) * dist
		if not field.blocks_player(q, false) and not field.blocks_player(pp + d.rotated(a) * dist * 0.5, false):
			return q
	return null


var _bot_pick = null              # gewählte Quelle (bleibt, bis sie leer ist; sonst pendelt der Bot)
var _bot_pick_t := 0.0
var _bot_bad := {}
var _bot_last := Vector2(9999, 9999)
var _bot_stuck_t := 0.0
var _bot_best := 1.0e9
var _bot_detour := Vector2.ZERO
var _bot_detour_t := 0.0


func _bot_keep(n) -> bool:
	return n != null and not n.gone and room_for(n.res) >= 1.0 and not _bot_bad.has(n) and not node_locked(n)


func _bot_choose(n, pp: Vector2):
	if n == null:
		return null
	if n != _bot_pick:
		_bot_pick = n
		_bot_pick_t = 0.0
	return _stand(n, pp)


func _bot_decide(pp: Vector2):
	if hero.mounted:
		hero.dismount()
	if vulkan != null and phase == "explore":
		var cool = vulkan.bot_cool(pp)       # Vulkaninsel: zu heiß -> erst abkühlen
		if cool != null:
			return cool
	if mining != null and not mining.gone and room_for(mining.res) >= 1.0:
		_bot_pick_t = 0.0
		return pp
	_bot_pick_t += 0.4
	if _bot_pick != null and _bot_pick_t > 30.0:
		_bot_bad[_bot_pick] = true           # nicht erreichbar: andere Quelle wählen
		_bot_pick = null
	match phase:
		"siege", "relief":
			var z = outpost.zentrale
			if z != null and z.alive:
				return field.center(field.idx(z.mid - outpost.s * 5.5))    # hinter der Zentrale, geschützt von Mauern und Türmen
			if elite != null and elite.st != 2:
				# Zentrale gefallen: der Elitegegner kommt nicht mehr von selbst – auf Schussweite heran (wie ein Spieler)
				var away: Vector2 = pp - elite.p
				return elite.p + (away.normalized() if away.length_squared() > 0.01 else Vector2.RIGHT) * 9.0
			return respawn_point()
		"explore":
			if loads >= 2:
				if can_go_home():
					go_home()
				return outpost.zentrale.mid + outpost.s * 4.5 if outpost.zentrale != null else outpost.C
			if weight >= cap * 0.55:
				return outpost.depot_pos
			if _bot_keep(_bot_pick):
				return _stand(_bot_pick, pp)
			var n = _bot_node_any(pp, true)
			if n != null:
				return _bot_choose(n, pp)
			return outpost.depot_pos
	# Aufbau: nächster Platz in Reihenfolge
	for key in BOT_ORDER:
		if not outpost.pads.has(key):
			continue
		var pad = outpost.pads[key]
		if pad.done or pad.locked:
			continue
		var due: Dictionary = pad.due()
		for r in D.RES:
			if due.has(r) and float(loot.get(r, 0.0)) >= 1.0:
				return pad.stand_point(pp)
		# fehlender Rohstoff: abbauen gehen (oder zuerst bezahlen, wenn der Rucksack voll ist)
		for r in D.RES:
			if due.has(r):
				if room_for(r) < 1.0:
					continue
				if _bot_keep(_bot_pick) and _bot_pick.res == r:
					return _stand(_bot_pick, pp)
				var n2 = _nearest_node(r, pp)
				if n2 != null:
					return _bot_choose(n2, pp)
		break
	if _bot_keep(_bot_pick):
		return _stand(_bot_pick, pp)
	var n3 = _bot_node_any(pp, false)
	if n3 != null:
		return _bot_choose(n3, pp)
	return respawn_point()


func _bot_node_any(pp: Vector2, outer: bool):
	var best = null
	var bd := 1.0e9
	for n in nodes:
		if n.gone or room_for(n.res) < 1.0 or _bot_bad.has(n) or node_locked(n):
			continue
		if not _barriers_open() and n.ring > 0:
			continue
		var d: float = n.p.distance_squared_to(pp)
		if outer and n.ring == 0:
			d += 400.0
		if d < bd:
			bd = d
			best = n
	return best


func _stand(n, pp: Vector2) -> Vector2:
	var best: Vector2 = n.p + Vector2(2, 0)
	var bd := 1.0e9
	for o in [Vector2(2, 0), Vector2(-2, 0), Vector2(0, 2), Vector2(0, -2), Vector2(2, 2), Vector2(-2, 2), Vector2(2, -2), Vector2(-2, -2)]:
		var q: Vector2 = n.p + o * (0.8 if o.x != 0 and o.y != 0 else 1.0)
		if field.blocks_player(q):
			continue
		var d := q.distance_squared_to(pp)
		if d < bd:
			bd = d
			best = q
	return best
