extends "res://src/world.gd"
## Die Hauptbasis: frei bebaubares Raster (wie in Aufbauspielen), Friedensbetrieb mit Bauen,
## Verschieben und Einsammeln – und die Flut am siebten Tag bzw. der tägliche Übungsalarm.

const Structure = preload("res://src/structure.gd")

const HALF := 22                 # halbes größtes Raster (44 Felder)
const FIELD_N := 66              # Kartenfelder je Seite (132 Meter)
const SPAWN_DIST := 60.0
const DIR_VEC := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
const DIR_NAME := ["Norden", "Osten", "Süden", "Westen"]
const WALL_HIT := ["wall_hit_wood", "wall_hit_stone", "wall_hit_metal"]
const WALL_BREAK := ["wall_break_wood", "wall_break_stone", "wall_break_metal"]
const Bubble = preload("res://src/bubble.gd")
const UI = preload("res://src/ui.gd")
const BaseNature = preload("res://src/base_nature.gd")
const Weather = preload("res://src/weather.gd")
const Wildlife = preload("res://src/wildlife.gd")


class WallSeg:
	var alive := true
	var mid := Vector2.ZERO
	var cost := 30.0
	var blocks_player := true      # Mauern sperren Helden, Fahrzeuge und Bewohner
	var passable := false
	var tier := 0                   # 0 Holz, 1 Stein, 2 Metall
	var site := false               # noch im Bau: sperrt schon, hat aber nur ein Viertel Leben
	var hp := 100.0
	var max_hp := 100.0
	var radius := 1.0
	var x := 0
	var y := 0
	var id := 0
	var shielded := false
	var owner_ref
	var _taken := 0.0
	var _stamp := 0.0

	func hurt(d: float, force := false) -> void:
		if not alive or owner_ref.barrier_t > 0.0 or G.ch("god_base"):
			return
		d *= owner_ref.dmg_factor(self)
		if shielded:
			d *= 0.5
		if not force:
			if owner_ref.time - _stamp > 1.0:
				_stamp = owner_ref.time
				_taken = 0.0
			var cap := maxf(max_hp * 0.22, 60.0)
			if _taken >= cap:
				return
			d = minf(d, cap - _taken)
			_taken += d
		hp -= d
		Sfx.play_at(WALL_HIT[tier], Vector3(mid.x, 0, mid.y), -14.0, 1.0, 0.1)
		if hp <= 0.0:
			alive = false
			hp = 0.0
			owner_ref.on_wall_destroyed(self)

	func repair(ratio: float) -> void:
		if alive:
			hp = minf(max_hp, hp + max_hp * ratio)


const Humanoid = preload("res://src/humanoid.gd")
const NpcBoard = preload("res://src/npc_board.gd")

var _settlers: Array = []        # alt (Paket 2: ersetzt durch npc_board)
var npc_board                    # Bewohner mit Berufen und Aufgaben (src/npc_board.gd)
var _drones: Array = []          # {n: Node3D, ph: float, r: float}

signal selection_changed
signal state_changed
signal battle_ended

var nodes := {}                  # Gebäude-ID -> Structure
var walls: Array = []
var bunker_node: Node3D
var selected_id := -1
var place_key := ""
var move_id := -1
var ghost_cell := Vector2i(22, 22)
var ghost_rot := 0
var ghost_ok := false
var wave_idx := 0
var wave_count := 0
var break_left := 0.0
var result := {}
var flood := {}
var kills_start := 0

var _ghost: Node3D
var _ghost_plate: MeshInstance3D
var _sel_ring: MeshInstance3D
var _mm_post: Array = []         # je Mauerart ein MultiMesh
var _mm_link: Array = []
var _mm_site: MultiMesh
var enclosed := false           # Basis zugemauert und ohne Tor?
var bubbles_open := 0           # sichtbare Sammelblasen (für den Knopf "Alles einsammeln")
var _focus_t := 0.0
var _walls_dirty := false
var gate_links := 0             # halbe Verbindungsstücke zwischen Mauer und Tor (für Tests)
var _queue: Array = []
var _spawn_t := 0.0
var _spawn_gap := 0.2
var _idle_t := 0.0
var _mines: Array = []
var _mine_t := 0.0
var _sec := 0.0
var _press_pos := Vector2.ZERO
var _press_t := 0.0
var _dragging := false
var _bot_t := 0.0
var _cam_pan := Vector3.ZERO
var _last_paint := Vector2i(-1, -1)
var _wall_tier := -1
const Guide = preload("res://src/guide.gd")     # Paket F: Warteschlange, Tutorial-Flut, Schwierigkeit, Gebäudeschaden
var queue_mode := false          # Platz wählen für einen vorgemerkten Bau (alle Drohnen beschäftigt)
var tutorial_flood := false      # laufende Flut ist die leichte Tutorial-Flut (ohne Verlust)
# ---- V6 Paket B: Belagerung, Wetter, Rückblick, Layout-Test, Mauer-Schäden, Funde, Wasser, Verletzte
const Siege = preload("res://src/siege.gd")
const FloodWeather = preload("res://src/flood_weather.gd")
const FloodReplay = preload("res://src/flood_replay.gd")
const BasisLife = preload("res://src/basis_life.gd")
const BState = preload("res://src/basis_state.gd")
const LayoutCode = preload("res://src/layout_code.gd")
var life: Node3D                 # basis_life.gd
var replay: Node                 # flood_replay.gd (nur während einer Flut)
var layout_test := false         # laufende Flut ist ein Layout-Test (ohne Verlust, Aufbau danach zurück)


func _ready() -> void:
	mode = "peace"
	setup_common(D.AREAS[0], Vector2(-FIELD_N, -FIELD_N), FIELD_N, FIELD_N, D.CELL)
	cam.bounds = Rect2(-52, -52, 104, 104)
	# Wege zeichnet die Bodenmaske der lebendigen Basis (base_nature.gd)
	make_ground(Vector2(-FIELD_N, -FIELD_N), Vector2(FIELD_N * 2, FIELD_N * 2), [], 1.6)
	_make_scenery()
	_make_wall_meshes()
	_sel_ring = MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.9
	tor.outer_radius = 1.0
	tor.rings = 32
	tor.ring_segments = 4
	_sel_ring.mesh = tor
	_sel_ring.material_override = MK.glow(D.C_GOLD)
	_sel_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sel_ring.visible = false
	add_child(_sel_ring)
	_ghost_plate = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1, 0.12, 1)
	_ghost_plate.mesh = bm
	_ghost_plate.material_override = MK.glow(Color(0.3, 1.0, 0.4, 0.5), true)
	_ghost_plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost_plate.visible = false
	add_child(_ghost_plate)
	_sync()
	_make_life()
	life = BasisLife.new()
	add_child(life)
	life.setup(self)
	var sp := respawn_point()
	spawn_hero(String(P.d.hero_sel), sp)
	P.buildings_changed.connect(_sync)
	P.pickups_changed.connect(_sync_pickups)
	P.building_done.connect(_on_built)
	P.level_up.connect(_on_level)
	G.next_wave_pressed.connect(skip_break)
	Sfx.loop("amb", Sfx.ambience(theme), -21.0)
	Music.set_mood("peace")


func _exit_tree() -> void:
	if P.buildings_changed.is_connected(_sync):
		P.buildings_changed.disconnect(_sync)
	if P.pickups_changed.is_connected(_sync_pickups):
		P.pickups_changed.disconnect(_sync_pickups)
	if P.building_done.is_connected(_on_built):
		P.building_done.disconnect(_on_built)
	if P.level_up.is_connected(_on_level):
		P.level_up.disconnect(_on_level)


func _on_built(id: int) -> void:
	var s: Node3D = nodes.get(id)
	if s != null and fx != null:
		fx.confetti(Vector3(s.mid.x, 1.0, s.mid.y))
		load("res://src/build_fx.gd").play(s)              # Paket G2: Teile fliegen ein, Staub
	if s != null and npc_board != null:
		npc_board.cheer_near(s.mid, 10.0, 1.5)


func _on_level(_lv: int) -> void:
	if hero != null and fx != null:
		fx.confetti(hero.global_position, 6)
		hero.body.cheer(1.5)


func respawn_point() -> Vector2:
	if bunker_node != null:
		return bunker_node.mid + Vector2(0, bunker_node.radius + 2.5)
	return Vector2(0, 6)


# ---------------------------------------------------------------- Kulisse
## Lebendige Basis (V3, Paket 5): Wiese, Blumen, Wege, Wald, Bach, Küste (base_nature.gd), Wind, Tageszeit,
## Regen (weather.gd) und Tiere (wildlife.gd).
func _make_scenery() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240
	wind3 = true
	nature = BaseNature.new()
	add_child(nature)
	nature.setup(self)
	nature.make_forest(rng)
	nature.make_coast(rng)
	# Wegweiser an den Zufahrten
	for d in 4:
		var v: Vector2 = DIR_VEC[d]
		var sp := v * 47.0 + v.orthogonal() * 7.5
		place_model("p_signpost", Vector3(sp.x, 0, sp.y), atan2(-v.x, -v.y))
	scatter_commit()
	make_ambient("gruental")
	weather = Weather.new()
	add_child(weather)
	weather.setup(self, nature)
	# Wege und Tiere brauchen die Gebäude: erst nach dem ersten Abgleich (_sync) anlegen
	nature.rebuild.call_deferred()
	_make_wildlife.call_deferred()
	# Kartenrand ist fest
	field.block_rect(Vector2(-FIELD_N, -FIELD_N), Vector2(FIELD_N, -FIELD_N + 2.0))
	field.block_rect(Vector2(-FIELD_N, FIELD_N - 2.0), Vector2(FIELD_N, FIELD_N))
	field.block_rect(Vector2(-FIELD_N, -FIELD_N), Vector2(-FIELD_N + 2.0, FIELD_N))
	field.block_rect(Vector2(FIELD_N - 2.0, -FIELD_N), Vector2(FIELD_N, FIELD_N))


var wildlife: Node3D


func _make_wildlife() -> void:
	if not is_inside_tree():
		return
	wildlife = Wildlife.new()
	add_child(wildlife)
	wildlife.setup(self, nature)


func _make_wall_meshes() -> void:
	var all: Array = []
	for tier in 3:
		for kind in 2:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = Models.wall_post(tier) if kind == 0 else Models.wall_link(tier)
			(_mm_post if kind == 0 else _mm_link).append(mm)
			all.append(mm)
	_mm_site = MultiMesh.new()
	_mm_site.transform_format = MultiMesh.TRANSFORM_3D
	_mm_site.mesh = Models.wall_site()
	all.append(_mm_site)
	for mm in all:
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = MK.mat_lin() if Models.has_glb("wall_post_0") else MK.mat()
		mi.custom_aabb = AABB(Vector3(-50, -1, -50), Vector3(100, 8, 100))
		add_child(mi)


## Wer ein Tor öffnet: Held (auch im Fahrzeug) und sichtbare Bewohner.
func friends() -> Array:
	var out: Array = []
	if hero != null and hero.alive:
		out.append(hero.pos2())
	if npc_board != null:
		for n in npc_board.npcs:
			if not n.hidden:
				out.append(n.pos)
	return out


## Bewohner mit Berufen (npc_board.gd), Drohnen kreisen über der Basis.
func _make_life() -> void:
	var bl := P.bunker_level()
	npc_board = NpcBoard.new(self)
	add_child(npc_board)
	for i in (1 if bl < 5 else 2):
		var dn := Models.glb("p_drone")
		add_child(dn)
		_drones.append({"n": dn, "ph": _rng.randf() * TAU, "r": 9.0 + i * 7.0})


func _tick_life(dt: float) -> void:
	npc_board.update(dt)
	for d in _drones:
		var n: Node3D = d.n
		var a: float = time * 0.35 + d.ph
		var r: float = d.r
		n.position = Vector3(cos(a) * r, 7.0 + sin(time * 1.7 + d.ph) * 0.5, sin(a) * r)
		n.rotation.y = -a
		var rotor := Models.find(n, "spin_rotor")
		if rotor != null:
			rotor.rotate_object_local(Vector3.UP, dt * 30.0)


## Antippen eines Bewohners: Schild mit Name, Beruf und Tätigkeit.
func _tap_npc(sp: Vector2) -> bool:
	var st = get_node_or_null("Geschichte")              # V6 Paket E: gerettete Figuren
	if st != null and st.tap(sp):
		return true
	return npc_board != null and npc_board.tap(sp)


## Nach der Flut (Paket 2): der Bunker steht sofort voll da, andere Gebäude behalten ihren Schaden
## (zerstörte stehen mit D.NPC_RUBBLE_HP Leben wieder) – Handwerker reparieren sie dann nach und nach.
func _restore_after_flood(s) -> void:
	if s == bunker_node or s.gate:
		s.restore()
		return
	var keep: float = s.hp if s.alive else s.max_hp * D.NPC_RUBBLE_HP
	s.restore()
	s.hp = clampf(keep, 1.0, s.max_hp)
	s._update_damage()
	if s.hp < s.max_hp:
		s._show_bar()


# ---------------------------------------------------------------- Raster
func cell_min(x: int, y: int) -> Vector2:
	return Vector2((x - HALF) * D.CELL, (y - HALF) * D.CELL)


func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / D.CELL)) + HALF, int(floor(p.y / D.CELL)) + HALF)


func rect_center(x: int, y: int, s: Vector2i) -> Vector2:
	return cell_min(x, y) + Vector2(s.x, s.y) * D.CELL * 0.5


## Gleicht die Welt mit dem Spielstand ab (nur Geändertes wird neu gebaut).
func _sync() -> void:
	if mode != "peace":
		return
	var seen := {}
	walls.clear()
	var tier := P.wall_tier_built()
	var wall_base: float = float(D.BUILDINGS.wall.hp) * (1.0 + P.cmd_bonus("wall_hp")) * (1.0 + P.outpost_bonus("wall_hp"))
	bunker_node = null
	for b in P.d.buildings:
		var id := int(b.id)
		if b.key == "wall":
			var w := WallSeg.new()
			w.x = int(b.x)
			w.y = int(b.y)
			w.id = id
			w.mid = cell_min(w.x, w.y) + Vector2(1, 1)
			w.tier = clampi(int(b.level) - 1, 0, 2)
			w.site = P.is_building(b) and not bool(b.get("up", false))
			w.max_hp = wall_base * float(D.WALL_TIERS[w.tier].hp)
			w.hp = w.max_hp * (0.25 if w.site else clampf(1.0 - float(b.get("dmg", 0.0)), 0.05, 1.0))     # V6 Paket B: Schaden bleibt
			w.cost = 22.0 + w.hp * 0.03
			w.owner_ref = self
			walls.append(w)
			continue
		seen[id] = true
		var building := P.is_building(b)
		var first: bool = building and not bool(b.get("up", false))
		var sg := "%s|%d|%d|%d|%d|%s|%d|%s|%d" % [b.key, int(b.x), int(b.y), int(b.rot), int(b.level), building, tier if b.key == "bunker" else 0, b.get("clear", false), Research.count()]
		var s: Node3D = nodes.get(id)
		if s == null or s.sig != sg:
			if s != null:
				s.queue_free()
			s = Structure.new()
			add_child(s)
			var size := P.size_of(b.key, int(b.rot))
			s.setup(b, b.key, int(b.level), size, rect_center(int(b.x), int(b.y), size), int(b.rot), first)
			if building and not first:
				s._make_site()
			if not first:
				Guide.apply_damage(s, b)
			s.sig = sg
			nodes[id] = s
		if b.key == "bunker":
			bunker_node = s
			_name_sign(s)
	for id in nodes.keys():
		if not seen.has(id):
			nodes[id].queue_free()
			nodes.erase(id)
			if selected_id == id:
				select(-1)
	_rebuild_lists()
	_walls_dirty = true
	_wall_tier = tier
	enclosed = P.enclosed()
	_unstick()
	_update_selection()
	_check_production()
	_sync_pickups()


## Steht der Held nach einem Bau in einem gesperrten Feld, rückt er auf das nächste freie Feld (bevorzugt zur Bunkerseite).
func _unstick() -> void:
	if hero == null or not field.blocks_player(hero.pos2()):
		return
	var p: Vector2 = hero.pos2()
	var c := world_to_cell(p)
	var home: Vector2 = bunker_node.mid if bunker_node != null else Vector2.ZERO
	var best := p
	var bs := 1.0e9
	for r in range(1, 7):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var q := cell_min(c.x + dx, c.y + dy) + Vector2(1, 1)
				if field.blocks_player(q):
					continue
				var sc := q.distance_to(p) + q.distance_to(home) * 0.08
				if sc < bs:
					bs = sc
					best = q
		if bs < 1.0e8:
			break
	hero.global_position = Vector3(best.x, 0, best.y)


func _rebuild_lists() -> void:
	structures.clear()
	towers = towers.filter(func(t): return is_instance_valid(t) and t.life > 0.0)
	field.clear_structures()
	for id in nodes:
		var s: Node3D = nodes[id]
		if float(s.def.hp) <= 0.0:
			continue
		structures.append(s)
		var half := Vector2(s.size.x, s.size.y) * D.CELL * 0.5
		field.add_structure(s, s.mid - half, s.mid + half)
		if s.tower != null:
			towers.append(s.tower)
	for w in walls:
		structures.append(w)
		field.add_structure(w, w.mid - Vector2(1, 1), w.mid + Vector2(1, 1))
	goal_structure = bunker_node
	if bunker_node != null:
		field.set_goal(bunker_node.mid)


func on_wall_destroyed(w) -> void:
	_walls_dirty = true
	field.dirty = true
	fx.puff(Vector3(w.mid.x, 1.0, w.mid.y), Color(0.7, 0.6, 0.5), 14, 1.4)
	Sfx.play_at(WALL_BREAK[w.tier], Vector3(w.mid.x, 0, w.mid.y), -6.0, 1.0, 0.1)
	if replay != null:
		replay.on_wall(w)


func on_structure_destroyed(s) -> void:
	if replay != null and is_running():
		replay.on_building(s)
	if s == bunker_node and is_running():
		_finish(false)


func _update_walls() -> void:
	_walls_dirty = false
	var occ := {}
	var posts: Array = [[], [], []]
	var links: Array = [[], [], []]
	var sites: Array = []
	for w in walls:
		if w.alive:
			occ[w.x + w.y * 64] = w.tier
			posts[w.tier].append(Transform3D(Basis.IDENTITY, Vector3(w.mid.x, 0, w.mid.y)))
			if w.site:
				sites.append(Transform3D(Basis.IDENTITY, Vector3(w.mid.x, 0, w.mid.y)))
	for w in walls:
		if not w.alive:
			continue
		# Verbindung zum rechten und unteren Nachbarn in der schwächeren der beiden Bauarten
		var r = occ.get(w.x + 1 + w.y * 64)
		if r != null:
			links[mini(w.tier, int(r))].append(Transform3D(Basis.IDENTITY, Vector3(w.mid.x + 1.0, 0, w.mid.y)))
		var u = occ.get(w.x + (w.y + 1) * 64)
		if u != null:
			links[mini(w.tier, int(u))].append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(w.mid.x, 0, w.mid.y + 1.0)))
	# Mauerfeld neben einem Tor: halbes Verbindungsstück bis zur Torkante, damit keine Lücke bleibt
	gate_links = 0
	for id in nodes:
		var gs: Node3D = nodes[id]
		if not gs.gate or gs.b.is_empty():
			continue
		var along_x: bool = gs.size.x >= gs.size.y
		for e in 2:
			var cx: int = int(gs.b.x) + ((-1 if e == 0 else gs.size.x) if along_x else 0)
			var cy: int = int(gs.b.y) + (0 if along_x else (-1 if e == 0 else gs.size.y))
			var wt = occ.get(cx + cy * 64)
			if wt == null:
				continue
			var wm := cell_min(cx, cy) + Vector2(1, 1)
			var to_gate := (1.0 if e == 0 else -1.0) * 0.5
			var hb := Basis.IDENTITY if along_x else Basis(Vector3.UP, PI * 0.5)
			hb.x *= 0.5
			links[int(wt)].append(Transform3D(hb, Vector3(wm.x + (to_gate if along_x else 0.0), 0, wm.y + (0.0 if along_x else to_gate))))
			gate_links += 1
	for tier in 3:
		_fill_mm(_mm_post[tier], posts[tier])
		_fill_mm(_mm_link[tier], links[tier])
	_fill_mm(_mm_site, sites)
	if life != null:
		life.update_wall_damage()


func _fill_mm(mm: MultiMesh, list: Array) -> void:
	mm.instance_count = list.size()
	for i in list.size():
		mm.set_instance_transform(i, list[i])


# ---------------------------------------------------------------- Auswahl, Bauen, Verschieben
func editing() -> bool:
	return place_key != "" or move_id >= 0


func hero_locked() -> bool:
	return editing()


func select(id: int) -> void:
	selected_id = id
	_update_selection()
	selection_changed.emit()


func selected() -> Dictionary:
	if selected_id < 0:
		return {}
	return P.get_building(selected_id)


func _update_selection() -> void:
	for id in nodes:
		var s: Node3D = nodes[id]
		if s.tower != null:
			s.tower.show_range(id == selected_id and mode == "peace")
	var b := selected()
	if b.is_empty() or mode != "peace":
		_sel_ring.visible = false
		return
	var size := P.size_of(b.key, int(b.rot))
	var c := rect_center(int(b.x), int(b.y), size)
	var r: float = maxf(size.x, size.y) * D.CELL * 0.62
	_sel_ring.position = Vector3(c.x, 0.15, c.y)
	_sel_ring.scale = Vector3(r, 1.0, r)
	_sel_ring.visible = true


func begin_place(key: String, queue := false) -> void:
	if mode != "peace":
		return
	var why := P.can_build(key)
	if queue and (why == "Alle Baudrohnen sind beschäftigt" or why.begins_with("Es fehl")):
		why = ""
	if why != "":
		P.toast.emit(why)
		Sfx.play("error", -6.0)
		return
	cancel_edit()
	select(-1)
	place_key = key
	queue_mode = queue
	ghost_rot = 0
	var c := world_to_cell(hero.pos2() + Vector2(0, 5))
	_start_edit(c)


func begin_move(id: int) -> void:
	var b := P.get_building(id)
	if b.is_empty() or mode != "peace":
		return
	cancel_edit()
	move_id = id
	place_key = ""
	ghost_rot = int(b.rot)
	_start_edit(Vector2i(int(b.x), int(b.y)))


func _edit_key() -> String:
	if move_id >= 0:
		return String(P.get_building(move_id).get("key", "wall"))
	return place_key


func _start_edit(c: Vector2i) -> void:
	var key := _edit_key()
	_ghost = Node3D.new()
	add_child(_ghost)
	if key == "wall":
		var mi := MeshInstance3D.new()
		var wb := P.get_building(move_id) if move_id >= 0 else {}
		mi.mesh = Models.wall_post(clampi(int(wb.get("level", 1)) - 1, 0, 2))
		mi.material_override = MK.mat_lin() if Models.has_glb("wall_post_0") else MK.mat()
		_ghost.add_child(mi)
	elif D.BUILDINGS[key].has("tower"):
		var t := Tower.new()
		t.active = false
		_ghost.add_child(t)
		t.setup(D.BUILDINGS[key].tower, 1)
		t.show_range(true)
	else:
		var gb := P.get_building(move_id) if move_id >= 0 else {}
		_ghost.add_child(Models.building(key, int(gb.get("level", 1)), P.wall_tier_built()))
	_ghost_plate.visible = true
	ground_mat.set_shader_parameter("grid_alpha", 0.3)
	var o := P.grid_origin()
	var n := P.grid_size()
	ground_mat.set_shader_parameter("grid_min", cell_min(o, o))
	ground_mat.set_shader_parameter("grid_max", cell_min(o + n, o + n))
	_cam_pan = Vector3(rect_center(c.x, c.y, Vector2i(1, 1)).x, 0, rect_center(c.x, c.y, Vector2i(1, 1)).y)
	cam.override_target = _cam_pan
	_last_paint = Vector2i(-1, -1)
	set_ghost(c)
	state_changed.emit()


func set_ghost(c: Vector2i) -> void:
	var key := _edit_key()
	var size := P.size_of(key, ghost_rot)
	var o := P.grid_origin()
	var n := P.grid_size()
	c.x = clampi(c.x, o, o + n - size.x)
	c.y = clampi(c.y, o, o + n - size.y)
	ghost_cell = c
	ghost_ok = P.cells_free(c.x, c.y, size.x, size.y, move_id)
	var ctr := rect_center(c.x, c.y, size)
	_ghost.position = Vector3(ctr.x, 0.05, ctr.y)
	_ghost.rotation.y = -ghost_rot * PI * 0.5
	_ghost_plate.position = Vector3(ctr.x, 0.1, ctr.y)
	_ghost_plate.scale = Vector3(size.x * D.CELL, 1, size.y * D.CELL)
	(_ghost_plate.material_override as StandardMaterial3D).albedo_color = Color(0.3, 1.0, 0.4, 0.5) if ghost_ok else Color(1.0, 0.25, 0.25, 0.55)


func rotate_ghost() -> void:
	if editing():
		ghost_rot = (ghost_rot + 1) % 4
		set_ghost(ghost_cell)


func confirm_edit() -> bool:
	if not editing():
		return false
	if not ghost_ok:
		Sfx.play("error", -6.0)
		return false
	if move_id >= 0:
		P.move(move_id, ghost_cell.x, ghost_cell.y, ghost_rot)
		Sfx.play("build_move", -6.0)
		var id := move_id
		cancel_edit()
		select(id)
		return true
	var key := place_key
	if queue_mode:
		var qw := Guide.queue_build(key, ghost_cell.x, ghost_cell.y, ghost_rot)
		if qw != "":
			P.toast.emit(qw)
			Sfx.play("error", -6.0)
			return false
		P.toast.emit("%s vorgemerkt – startet, sobald eine Drohne frei ist" % String(D.BUILDINGS[key].name))
		cancel_edit()
		return true
	var b := P.place(key, ghost_cell.x, ghost_cell.y, ghost_rot)
	if b.is_empty():
		Sfx.play("error", -6.0)
		if P.can_build(key) != "":
			cancel_edit()
		return false
	Sfx.play("build_place", -6.0)
	var ctr := rect_center(ghost_cell.x, ghost_cell.y, P.size_of(key, ghost_rot))
	fx.puff(Vector3(ctr.x, 0.6, ctr.y), Color(0.9, 0.85, 0.7), 16, 1.2)
	# Mauern, Fallen und Schmuck: gleich weiterbauen
	var cat: String = D.BUILDINGS[key].cat
	if (cat == "wall" or cat == "deco" or cat == "trap") and P.can_build(key) == "":
		set_ghost(ghost_cell)
	else:
		cancel_edit()
		if cat != "wall":
			select(int(b.id))
	return true


## Mauer ziehen: setzt die Felder zwischen zwei Malpunkten (Bresenham), ohne Ecken zu überspringen.
func _paint_line(a: Vector2i, b: Vector2i) -> void:
	var d := b - a
	var steps := maxi(absi(d.x), absi(d.y))
	if steps <= 1:
		return
	var last := a
	for i in range(1, steps):
		var c := Vector2i(a.x + int(round(float(d.x) * i / steps)), a.y + int(round(float(d.y) * i / steps)))
		if c == last:
			continue
		# keine diagonalen Sprünge: erst waagerecht auffüllen
		if c.x != last.x and c.y != last.y:
			_paint_cell(Vector2i(c.x, last.y))
		_paint_cell(c)
		last = c
	if b.x != last.x and b.y != last.y:
		_paint_cell(Vector2i(b.x, last.y))


func _paint_cell(c: Vector2i) -> void:
	if not editing() or place_key != "wall":
		return
	set_ghost(c)
	if ghost_ok:
		confirm_edit()


func cancel_edit() -> void:
	if not editing():
		return
	place_key = ""
	move_id = -1
	queue_mode = false
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	_ghost_plate.visible = false
	ground_mat.set_shader_parameter("grid_alpha", 0.0)
	cam.override_target = null
	state_changed.emit()


func _pointer(sp: Vector2, pressed: bool, drag: bool) -> void:
	var g = cam.ground_at(sp)
	if g == null:
		return
	var c := world_to_cell(Vector2(g.x, g.z))
	if editing():
		var key := _edit_key()
		var size := P.size_of(key, ghost_rot)
		var target := c - Vector2i(int(size.x / 2), int(size.y / 2))
		set_ghost(target)
		# am PC setzt ein Klick sofort; Mauern lassen sich durch Ziehen "malen" (Paket F: auch mit dem Finger,
		# Felder dazwischen werden aufgefüllt, damit schnelles Ziehen keine Lücken lässt)
		var paint: bool = drag and key == "wall" and place_key != "" and not queue_mode
		if (paint or (pressed and not G.is_touch)) and ghost_cell != _last_paint:
			if paint and _last_paint != Vector2i(-1, -1):
				_paint_line(_last_paint, ghost_cell)
			_last_paint = ghost_cell
			if ghost_ok or pressed:
				confirm_edit()
		return
	if pressed and mode == "peace":
		if _tap_bubble(sp):
			return
		if _tap_npc(sp): return
		var occ := P.occupancy()
		var k := c.x + c.y * 64
		if occ.has(k):
			var id := int(occ[k])
			select(id)
			Sfx.play("click", -10.0)
			var s: Node3D = nodes.get(id)
			var b := P.get_building(id)
			if s != null and P.prod_stored(b) > 0:
				_collect(b, s)
		else:
			select(-1)


func _unhandled_input(event: InputEvent) -> void:
	if mode != "peace" or G.main.ui_blocked():
		return
	if G.is_touch:
		if event is InputEventScreenTouch:
			if event.pressed:
				_press_pos = event.position
				_press_t = time
				_last_paint = Vector2i(-1, -1)
			elif event.position.distance_to(_press_pos) < 28.0 and time - _press_t < 0.4:
				_pointer(event.position, true, false)
		elif event is InputEventScreenDrag and editing() and event.position.x > get_viewport().get_visible_rect().size.x * 0.45:
			if place_key == "wall" and _last_paint == Vector2i(-1, -1) and _press_pos.distance_to(event.position) < 80.0:
				_pointer(_press_pos, false, true)          # Mauer ziehen: das Startfeld zählt mit
			_pointer(event.position, false, true)
	else:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			if event.pressed:
				_last_paint = Vector2i(-1, -1)
				_pointer(event.position, true, false)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and editing():
			cancel_edit()
		elif event is InputEventMouseMotion and editing():
			_pointer(event.position, false, _dragging)
		elif event is InputEventKey and event.pressed and not event.echo and editing():
			if event.physical_keycode == KEY_R:
				rotate_ghost()
			elif event.physical_keycode == KEY_ENTER:
				confirm_edit()


# ---------------------------------------------------------------- Produktion und Abholungen
## Einmal je Sekunde: Sammelblasen über Produktionsgebäuden zeigen; läuft der Held heran, wird eingesammelt.
func _check_production() -> void:
	var open := 0
	for id in nodes:
		var s: Node3D = nodes[id]
		if not s.def.has("prod"):
			continue
		var st := P.prod_stored(s.b)
		if mode != "peace" or st < P.prod_bubble_min(s.b):
			s.set_bubble("")
			continue
		var cap := P.prod_cap(s.b)
		var r := String(s.def.prod)
		s.set_bubble("res_" + r, UI.fmt(st), 2 if st >= cap else (1 if st >= cap * 0.75 else 0))
		open += 1
		if hero != null and not editing() and hero.pos2().distance_to(s.mid) < s.radius + 3.0 and P.res(r) < P.cap(r):
			_collect(s.b, s)
			open -= 1
	bubbles_open = open
	if mode == "peace" and hero != null and not editing():
		for id in nodes:
			var s2: Node3D = nodes[id]
			if s2.gift != null and s2.gift.visible and hero.pos2().distance_to(s2.mid) < s2.radius + 1.6:
				_claim(s2)
				break


func _collect(b: Dictionary, s: Node3D) -> void:
	var before := P.prod_stored(b)
	var got := P.collect(int(b.id))
	if got > 0:
		var r: String = D.BUILDINGS[b.key].prod
		if s.bubble != null and G.hud != null and G.shots_dir == "":
			G.hud.fly_icons("res_" + r, s.bubble.screen_pos(cam.cam), r, clampi(6 + int(got / 40), 6, 12))
		fx.float_text(Vector3(s.mid.x, 5.0, s.mid.y), "+%d %s" % [got, D.RES_NAME[r]], D.RES_COLOR[r].lightened(0.3))
		Sfx.play("bubble_pop", -6.0, 1.0, 0.1)
		Sfx.play("res_" + r, -6.0, 1.0, 0.1)
		s.pop()
		if got >= before:
			s.set_bubble("")
		else:
			_check_production()


func collect_all() -> void:
	for id in nodes:
		var s: Node3D = nodes[id]
		if s.bubble != null and s.bubble.visible:
			_collect(s.b, s)
	# Paket F: auch Geschenke und Lieferungen abholen
	for id in nodes.keys():
		var s2: Node3D = nodes.get(id)
		if s2 != null and s2.gift != null and s2.gift.visible:
			_claim(s2)
	_check_production()


## Abholungen (tägliches Geschenk, Lieferungen …) als zweite Blase über dem passenden Gebäude.
func _sync_pickups() -> void:
	var used := {}
	if mode == "peace":
		for p in P.d.pickups:
			var target: Node3D = null
			for id in nodes:
				if nodes[id].key == String(p.at) and not used.has(id):
					target = nodes[id]
					used[id] = true
					break
			if target == null and bunker_node != null and not used.has(-1):
				target = bunker_node
				used[-1] = true
			if target == null:
				continue
			var bundle: Dictionary = p.bundle
			var icon := "res_gems"
			var text := ""
			for r in bundle:
				if r == "chest":
					icon = "chest_" + String(bundle[r])
				else:
					icon = "res_" + String(r)
					text = UI.fmt(float(bundle[r]))
				break
			target.set_gift(icon, text, int(p.id))
			target.set_meta("gift_on", true)
	for id in nodes:
		var s: Node3D = nodes[id]
		if s.gift != null and not (used.has(id) or (s == bunker_node and used.has(-1))):
			s.set_gift("")


func _claim(s: Node3D) -> void:
	var p: Dictionary = P.claim_pickup(int(s.gift.tag))
	if p.is_empty():
		s.set_gift("")
		return
	var bundle: Dictionary = p.bundle
	for r in bundle:
		if r != "chest" and G.hud != null and G.shots_dir == "":
			G.hud.fly_icons("res_" + String(r), s.gift.screen_pos(cam.cam), String(r), 8)
	Sfx.play("bubble_pop", -6.0)
	Sfx.play("ui_claim", -6.0)
	P.toast.emit(String(p.text))
	_sync_pickups()


## Antippen einer Blase hat Vorrang vor dem Gebäude darunter.
func _tap_bubble(sp: Vector2) -> bool:
	var best: Node3D = null
	var gift := false
	var bd: float = 64.0 * get_viewport().get_visible_rect().size.y / 720.0
	for id in nodes:
		var s: Node3D = nodes[id]
		for k in 2:
			var bub: Node3D = s.bubble if k == 0 else s.gift
			if bub != null and bub.visible:
				var dd: float = bub.screen_pos(cam.cam).distance_to(sp)
				if dd < bd:
					bd = dd
					best = s
					gift = k == 1
	if best == null:
		return false
	if gift:
		_claim(best)
	else:
		_collect(best.b, best)
	return true


## Kamera springt kurz zu diesem Gebäude und wählt es aus (Liste der laufenden Bauten).
func focus(id: int) -> void:
	var b := P.get_building(id)
	if b.is_empty() or mode != "peace" or editing():
		return
	var size := P.size_of(b.key, int(b.rot))
	var c := rect_center(int(b.x), int(b.y), size)
	cam.override_target = Vector3(c.x, 0, c.y)
	_focus_t = 2.5
	select(id)


# ---------------------------------------------------------------- Flut
func flood_preview(practice: bool, tutorial := false) -> Dictionary:
	var wk := int(P.d.week.number)
	var fd := D.flood_def(wk, P.bunker_level())
	if practice:
		fd.total = int(fd.total * D.PRACTICE_STRENGTH)
		fd.waves = mini(3, fd.waves)
		fd.boss = false
	elif bool(P.d.week.get("easier", false)):
		fd.total = int(fd.total * 0.85)
	# Gastfamilien (Kapitel 11.4): ab Woche 3 eine (25 %), ab Woche 10 zwei (zusammen 40 %)
	fd["guests"] = P.flood_guests()
	if G.arg("guest") != "":                       # Test: --guest=untote[,eis] erzwingt die Gastfamilien
		fd["guests"] = Array(G.arg("guest").split(","))
	fd["guest_share"] = D.flood_guest_share(wk) if not fd.guests.is_empty() else 0.0
	fd["guest_text"] = P.flood_guest_text()
	Guide.apply_flood(fd, practice, tutorial)
	if layout_test:
		LayoutCode.test_flood(fd)                    # V6 Paket B: Layout-Test in der Stärke der echten Flut
	FloodWeather.apply(fd, practice and not layout_test, self)     # V6 Paket B: Wetter der Flut
	return fd


func start_flood(practice: bool, tutorial := false) -> void:
	if mode != "peace" or bunker_node == null:
		return
	cancel_edit()
	select(-1)
	tutorial_flood = tutorial
	if tutorial:
		practice = true
	mode = "practice" if practice else "flood"
	flood = flood_preview(practice, tutorial)
	flood["mix"] = D.flood_mix(int(P.d.week.number))
	flood["dirs"] = P.d.week.dirs
	wave_count = int(flood.waves)
	wave_idx = 0
	result = {}
	horde.clear()
	horde.kills = 0
	coins.clear()
	clear_zones()
	_mines.clear()
	for s in structures:
		s.shielded = false
	# Fallen scharf schalten, Schildgeneratoren einschalten
	var tk := 1.0 + P.cmd_bonus("trap_dmg")
	for id in nodes:
		var s: Node3D = nodes[id]
		if s.constructing:
			continue
		var lv := int(s.b.level)
		match s.key:
			"stachel":
				add_zone("spike", s.mid, 1.3, 1.0e9, 26.0 * tk * (1.0 + 0.3 * (lv - 1)) * float(flood.hp), 30.0)
			"kleb":
				add_zone("glue", s.mid, 2.3, 1.0e9, 0.0)
			"mine":
				_mines.append({"s": s, "dmg": 160.0 * tk * (1.0 + 0.3 * (lv - 1)) * float(flood.hp)})
			"schild":
				Sfx.play("shield_hum", -6.0, 1.0, 0.5)
				for o in structures:
					if o.mid.distance_to(s.mid) < 16.0:
						o.shielded = true
	load("res://src/traps2.gd").arm(self)                 # Paket G2: Teergrube, Federbrett, Lockköder, Elektrozaun, Eisfalle
	_update_selection()
	_check_production()
	_sync_pickups()
	xp_factor = float(flood.hp)
	horde.siege = Siege.new(self) if G.arg("nosiege") == "" else null     # V6 Paket B: Brecher, Flieger, Leitern (--nosiege=1: Vergleich)
	FloodWeather.begin(self)
	replay = FloodReplay.new()
	add_child(replay)
	replay.setup(self)
	running = true
	ended = false
	hero.deaths = 0
	hero.global_position = Vector3(respawn_point().x, 0, respawn_point().y)
	Sfx.play("flood_horn", -2.0)
	Music.set_mood("battle")
	_next_wave()
	state_changed.emit()


func _next_wave() -> void:
	wave_idx += 1
	break_left = 0.0
	_idle_t = 0.0
	# spätere Wellen sind größer
	var wsum := 0.0
	for i in wave_count:
		wsum += 1.0 + i * 0.5
	var n := int(round(float(flood.total) * (1.0 + (wave_idx - 1) * 0.5) / wsum))
	var mix: Array = flood.mix
	var msum := 0.0
	for v in mix:
		msum += float(v)
	_queue.clear()
	# Gäste: Arten der Gastfamilien, nach Rolle gewichtet; in der ersten Welle erst die Hälfte
	var guests: Array = flood.get("guests", [])
	var gn := int(round(n * float(flood.get("guest_share", 0.0)) * (0.5 if wave_idx == 1 else 1.0))) if not guests.is_empty() else 0
	for i in gn:
		_queue.append(horde.pick_type(String(guests[i % guests.size()])))
	var sn := n - gn
	for t in mix.size():
		var cnt := int(round(sn * float(mix[t]) / msum))
		# neue Gegnertypen tauchen erst ab der zweiten Welle auf
		if t > 0 and wave_idx == 1:
			cnt = int(cnt / 2)
		for i in cnt:
			_queue.append(t)
	while _queue.size() < n:
		_queue.append(D.E_SLIME)
	horde.plan_wave(_queue, int(P.d.week.number), wave_idx, wave_count, n, guests)     # Paket G2: neue Rollen, Elite, Miniboss
	_queue.shuffle()
	if wave_idx == wave_count and flood.boss:
		_queue.append(D.E_BOSS)
	_spawn_gap = clampf(14.0 / maxf(_queue.size(), 1.0), 0.04, 0.5)
	_spawn_t = 1.0
	if wave_idx > 1:
		Sfx.play("wave", -4.0)
	state_changed.emit()


func enemies_left() -> int:
	return horde.alive + _queue.size()


func skip_break() -> void:
	if is_running() and break_left > 0.5:
		break_left = 0.05


func _spawn_one() -> void:
	var t: int = _queue.pop_back()
	var dirs: Array = flood.dirs
	var d := int(dirs[_rng.randi() % dirs.size()])
	var v: Vector2 = DIR_VEC[d]
	var p: Vector2 = v * SPAWN_DIST + v.orthogonal() * _rng.randf_range(-8.0, 8.0) + v * _rng.randf_range(-2.0, 2.0)
	if t == D.E_BOSS:
		# Boss der letzten Welle: der Boss der ersten Gastfamilie, ohne Gäste der Schleim-Boss
		var wk := int(P.d.week.number)
		var guests: Array = flood.get("guests", [])
		var area := 0
		if not guests.is_empty():
			area = maxi(0, D.AREA_FAMILY.find(String(guests[0])))
		var e = horde.spawn_boss(area, p, float(flood.hp) * (0.5 + 0.12 * wk), float(flood.dmg))
		if area == 0:
			e.special = ["summon", "spit", "slam"][wk % 3]
		P.toast.emit("%s greift an!" % horde.boss_name)
		Sfx.play("boss_arrive", -2.0)
		Music.set_mood("boss")
		cam.shake(0.3)
		return
	if t >= 1000:
		horde.spawn_planned(t, p, float(flood.hp), float(flood.dmg))       # Elite (+1000) oder Miniboss (+2000)
		return
	var ne = horde.spawn(t, p, float(flood.hp), float(flood.dmg), float(flood.dmg))
	if horde.siege != null:
		horde.siege.on_spawn(ne)                     # V6 Paket B: Leitern


func _tick_flood(dt: float) -> void:
	if break_left > 0.0:
		break_left -= dt
		if break_left <= 0.0:
			_next_wave()
		return
	if _queue.size() > 0:
		_spawn_t -= dt
		while _spawn_t <= 0.0 and _queue.size() > 0 and horde.alive < G.max_alive():
			_spawn_t += _spawn_gap
			_spawn_one()
		_spawn_t = maxf(_spawn_t, -0.2)
	else:
		_idle_t += dt
		if horde.alive <= 0 or _idle_t > 100.0:
			if wave_idx >= wave_count:
				if horde.alive <= 0 or _idle_t > 160.0:
					_finish(true)
			else:
				break_left = D.WAVE_BREAK
				fx.confetti(Vector3(bunker_node.mid.x, 3.0, bunker_node.mid.y), 5)
				hero.body.cheer(1.2)
				Sfx.play("wave_clear", -4.0)
				coins.collect_all()
				# kleine Reparatur zwischen den Wellen
				if bunker_node.alive:
					bunker_node.repair(P.cmd_bonus("bunker_heal") * (1.0 if wave_idx == 1 else 0.0))
				state_changed.emit()
	_mine_t -= dt
	if _mine_t <= 0.0 and _mines.size() > 0:
		_mine_t = 0.2
		for i in range(_mines.size() - 1, -1, -1):
			var mn: Dictionary = _mines[i]
			if horde.in_radius(mn.s.mid, 1.8).size() > 0:
				Sfx.play_at("mine_beep", Vector3(mn.s.mid.x, 0, mn.s.mid.y), -6.0, 1.6)
				blast(Vector3(mn.s.mid.x, 0.3, mn.s.mid.y), 5.5, mn.dmg)
				mn.s.model.visible = false
				_mines.remove_at(i)


func _finish(win: bool) -> void:
	if ended:
		return
	ended = true
	running = false
	_flush_coins()
	coins.collect_all()
	var ratio: float = bunker_node.hp / bunker_node.max_hp if win else 0.0
	var k: int = horde.kills
	if layout_test:
		result = LayoutCode.test_result(win, k)      # V6 Paket B: Layout-Test ohne Verlust und ohne Belohnung
	elif tutorial_flood:
		# Tutorial-Flut: kein Verlust, verbraucht nicht den Übungsalarm des Tages
		result = {"win": win, "coins": 0, "xp": 20}
		P.add_xp(20)
		P.d.stats.kills = int(P.d.stats.kills) + k
		result["practice"] = true
	elif flood.has("raid"):
		result = preload("res://src/liveops.gd").raid_result(win, k)     # Paket L: Weltboss-Angriff (eigene Abrechnung)
	elif mode == "practice":
		result = P.practice_done(win, k)
		result["practice"] = true
	else:
		result = P.flood_result(win, ratio, false, k)
		result["practice"] = false
	result["kills"] = k
	if not layout_test:
		Guide.flood_end(result, mode, win, tutorial_flood)
		BState.flood_end(self, result)               # V6 Paket B: Zusatzbeute (Nacht, Forschung), Bewertungs-Hinweis
	result["waves"] = wave_idx if win else wave_idx - 1
	result["hp_ratio"] = ratio
	if replay != null:
		var rp: Dictionary = replay.finish(result)  # V6 Paket B: Flut-Rückblick speichern
		result["replay"] = true
		if mode == "flood" and not layout_test and not tutorial_flood and not flood.has("raid"):
			var lost := 0
			var br := 0
			for wv in rp.get("waves", []):
				lost += (wv.lost as Array).size()
				br += (wv.br as Array).size()
			result["injured"] = BState.injuries_after(win, ratio, lost, br)
	if not layout_test:
		P.add_hero_xp(hero.key, (40.0 + 25.0 * wave_idx) * (1.0 if win else 0.5) * (0.5 if mode == "practice" else 1.0))
	if win and mode == "practice":
		Sfx.play("practice_done", -2.0)
	else:
		Sfx.play("win" if win else "lose", -2.0)
	if win:
		hero.body.cheer(3.0)
		fx.confetti(hero.global_position, 8)
		fx.confetti(Vector3(bunker_node.mid.x, 4.0, bunker_node.mid.y), 8)
	battle_ended.emit()
	state_changed.emit()


## Nach dem Ergebnisbildschirm: Basis wiederherstellen, zurück in den Friedensbetrieb.
func back_to_peace() -> void:
	if life != null and not tutorial_flood and not layout_test:
		life.store_wall_damage()                     # V6 Paket B: Mauern behalten ihren Schaden
	FloodWeather.finish(self)
	if horde.siege != null:
		horde.siege.clear()
		horde.siege = null
	if replay != null:
		replay.queue_free()
		replay = null
	horde.clear()
	coins.clear()
	clear_zones()
	_mines.clear()
	for t in towers:
		if is_instance_valid(t) and t.life > 0.0:
			t.queue_free()
	for s in structures:
		if s is WallSeg:
			s.alive = true
			s.hp = s.max_hp * (0.25 if s.site else 1.0)
		elif layout_test:
			s.restore()                              # V6 Paket B: Layout-Test hinterlässt keinen Schaden
		else:
			_restore_after_flood(s)
	for id in nodes:
		nodes[id].model.visible = true
	mode = "peace"
	running = false
	ended = false
	tutorial_flood = false
	if layout_test:
		layout_test = false
		LayoutCode.test_restore()                    # V6 Paket B: eigener Aufbau zurück
	Music.set_mood("peace")
	if not hero.alive:
		hero._do_respawn()
	hero.hp = hero.max_hp
	_sync()
	field.dirty = true
	if npc_board != null:
		npc_board.nav.dirty = true
	state_changed.emit()


func bot_goal():
	if mode == "peace":
		return null
	if hero.hp < hero.max_hp * 0.35:
		return respawn_point()
	var c = coins.nearest_ground(hero.pos2(), 14.0)
	var e = horde.nearest(bunker_node.mid, 30.0)
	if e != null:
		var to: Vector2 = e.p - bunker_node.mid
		return bunker_node.mid + to.normalized() * minf(to.length() - 6.0, 16.0)
	if c != null:
		return c
	var d := int(flood.dirs[0])
	return bunker_node.mid + DIR_VEC[d] * 12.0


# ---------------------------------------------------------------- Schleife
func _physics_process(dt: float) -> void:
	tick_common(dt)
	_tick_life(dt)
	if _walls_dirty:
		_update_walls()
	if mode == "peace":
		_sec += dt
		if _sec >= 1.0:
			_sec = 0.0
			_check_production()
			if _wall_tier != P.wall_tier():
				_sync()
		if _focus_t > 0.0:
			_focus_t -= 1.0
			if _focus_t <= 0.0 and not editing():
				cam.override_target = null
		if editing() and not G.main.ui_blocked():
			var iv := G.move_vector()
			if iv != Vector2.ZERO:
				var wd: Vector2 = cam.screen_to_world_dir(iv) * 30.0 * dt
				_cam_pan = Vector3(clampf(_cam_pan.x + wd.x, -46, 46), 0, clampf(_cam_pan.z + wd.y, -46, 46))
				cam.override_target = _cam_pan
		return
	if is_running():
		_tick_flood(dt)
		if G.autotest != "":
			_bot_t -= dt
			if _bot_t <= 0.0:
				_bot_t = 1.0
				for i in 4:
					if hero.skills.ready(i):
						hero.skills.use(i)
				skip_break()


## Schild mit dem Bunkernamen über dem Bunker (so finden dich andere im Funkturm).
func _name_sign(s: Node3D) -> void:
	var lb: Label3D = s.get_node_or_null("NameSign")
	if lb == null:
		lb = Label3D.new()
		lb.name = "NameSign"
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.pixel_size = 0.014
		lb.font_size = 56
		lb.outline_size = 16
		lb.outline_modulate = Color(0.04, 0.1, 0.22, 0.9)
		lb.modulate = Color("FFD84A")
		lb.no_depth_test = true
		lb.render_priority = 5
		s.add_child(lb)
	lb.text = P.bunker_name()
	lb.position = Vector3(0, 7.5 + 0.3 * int(P.bunker_level()), 0)
