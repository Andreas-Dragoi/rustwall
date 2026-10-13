extends Node3D
## V6 Paket M – Spielmodi in der Expedition (wird von main._swap an jede neue Welt gehängt, wirkt nur in der Expedition):
##   Höhlen:     ab Gebiet 2 je Besuch 1–2 Höhleneingänge (Blender: cv_<thema>_entry). Wer 1 s im Eingang steht, geht
##               hinein: die Expedition wird ausgehängt (sie ruht), die Höhle (src/cave_world.gd) läuft als eigene Welt
##               und hängt sie beim Rückweg wieder ein. Beute, Münzen und besiegte Gegner zählen zur Expedition.
##   Ladefläche: die Pritsche hat einen zweiten Rucksack. Steht der Held mit gefülltem Rucksack am Fahrzeug, lädt er um;
##               die Ladung liegt sichtbar auf der Ladefläche (Teil-Modelle aus blender/cargo.py, Gitter v_pickup_rack).
##               Am Depot der Außenbasis wird sie abgeladen. Geht das Fahrzeug kaputt, fällt die Ladung als Haufen herab.

const D = preload("res://src/data.gd")
const DM = preload("res://src/data_modi.gd")
const Modi = preload("res://src/modi.gd")
const Models = preload("res://src/models.gd")
const CD = preload("res://src/companion_data.gd")
const Anim = preload("res://src/anim.gd")

var ex: Node3D                         # die Expedition
var caves: Array = []                  # {p (Eingangspunkt), n, theme, done, idx, seed, ring, seen}
var bed := {}                          # Ladung der Ladefläche: Rohstoff -> Menge
var bed_weight := 0.0
var bed_cap := 0.0
var _rack: Node3D
var _cargo_l: Node3D
var _cargo_r: Node3D
var _cargo_sig := "-"
var _hold := 0.0
var _hold_i := -1
var _armed := {}                       # Eingang i: erst wieder betreten, wenn man einmal weg war
var _t := 0.0
var _anims: Array = []
var _veh_dead := false
var _msg_t := 0.0
var _bed_t := 0.0
var _bed_pill: Control
var _bed_label: Label


static func attach(world: Node3D) -> Node3D:
	if world == null or world.get("mode") != "exp" or not world.has_method("add_pack"):
		return null
	var n = (load("res://src/modi_exp.gd") as GDScript).new()
	n.name = "ModiExp"
	n.ex = world
	world.add_child(n)
	return n


func _ready() -> void:
	_setup.call_deferred()


func _setup() -> void:
	if not is_instance_valid(ex):
		return
	_place_caves()
	_setup_bed()


# ================================================================= Höhlen: Eingänge
func _place_caves() -> void:
	if int(ex.area) < DM.CAVE_FROM_AREA or String(ex.mission) == "befreiung":
		return
	if G.arg("caves") == "0":
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("rw-caves-%d-%d-%d" % [int(ex.area), int(ex.diff), P.day_index()])
	if G.arg("seed") != "":
		rng.seed = int(G.arg("seed")) + 77
	var n := 1 + (1 if rng.randf() < 0.55 else 0)
	if G.arg("caves") != "":
		n = clampi(int(G.arg("caves")), 1, DM.CAVE_MAX)
	var theme := Modi.cave_theme(int(ex.area))
	# Solange die Sperren stehen, ist außerhalb der Landezone alles fest (expedition.gd): zum Platzieren das echte Feld nehmen
	var outer: PackedByteArray = ex.get("_outer_solid") if ex.get("_outer_solid") != null else PackedByteArray()
	var keep := PackedByteArray()
	if not outer.is_empty():
		keep = ex.field.solid
		ex.field.solid = outer
	var tries := 0
	var start: Vector2 = ex.hero.pos2() if ex.hero != null else Vector2.ZERO
	while caves.size() < n and tries < 400:
		tries += 1
		# erste Höhle in der Landezone (immer erreichbar), die zweite im Mittelring
		var r0 := 18.0 if caves.is_empty() else D.EXP_RING_LAND + 10.0
		var r1 := D.EXP_RING_LAND - 8.0 if caves.is_empty() else D.EXP_RING_MID - 10.0
		var a := rng.randf() * TAU
		var c := Vector2(cos(a), sin(a)) * rng.randf_range(r0, r1)
		if not _free_spot(c, start):
			continue
		var yaw := PI * 0.25 + rng.randf_range(-0.35, 0.35)   # Öffnung zeigt zur Kamera (Schrägsicht von rechts vorn)
		var front := Vector2(sin(yaw), cos(yaw))
		var mouth := c + front * 2.9
		if ex.field.blocks_player(mouth) or ex.field.blocks_player(mouth + front * 2.0):
			continue
		var node: Node3D = null
		var mdl := "cv_%s_entry" % theme
		if Models.has_glb(mdl):
			node = Models.glb(mdl)
			node.position = Vector3(c.x, 0, c.y)
			node.rotation.y = yaw
			add_child(node)
			_anims.append_array(Anim.collect(node))
			_torch_light(node, Vector3(-1.95, 2.0, 2.1))
			_torch_light(node, Vector3(1.95, 2.0, 2.1))
		_block_cave(c, front)
		var ring: MeshInstance3D = ex.ring_mesh(1.3, Color(1.0, 0.75, 0.35)) if ex.has_method("ring_mesh") else null
		if ring != null:
			ring.position = Vector3(mouth.x, 0.1, mouth.y)
		caves.append({"p": mouth, "c": c, "n": node, "theme": theme, "done": false, "idx": caves.size(), "seed": rng.randi(), "ring": ring, "seen": false})
	if not outer.is_empty():
		ex._outer_solid = ex.field.solid
		ex.field.solid = keep
		for cv in caves:                                     # Höhlen in der Landezone auch im gültigen Feld eintragen
			_block_cave(cv.c, (cv.p - cv.c).normalized())
		ex.field.dirty = true
	if not caves.is_empty():
		var msg := "In diesem Gebiet gibt es eine Höhle – Fackeln zeigen den Eingang." if caves.size() == 1 else "In diesem Gebiet gibt es %d Höhlen – Fackeln zeigen den Eingang." % caves.size()
		P.toast.emit.call_deferred(msg)


## Felshügel fest, die Öffnung bleibt frei.
func _block_cave(c: Vector2, front: Vector2) -> void:
	ex.field.block_circle(c - front * 0.8, 2.4)      # Hügel fest, Eingang (2,9 m vor der Mitte) bleibt frei
	ex.field.block_circle(c + front.orthogonal() * 2.4, 1.2)
	ex.field.block_circle(c - front.orthogonal() * 2.4, 1.2)


func _free_spot(c: Vector2, start: Vector2) -> bool:
	if c.distance_to(start) < 14.0:
		return false
	var op = ex.get("outpost")
	if op != null and c.distance_to(op.C) < 20.0:
		return false
	for k in 12:
		var a := TAU * k / 12.0
		for r in [0.0, 2.0, 3.6]:
			var q: Vector2 = c + Vector2(cos(a), sin(a)) * r
			if ex.field.blocks_player(q) or ex.field.is_solid(q):
				return false
	for nd in ex.get("nodes"):
		if not nd.gone and nd.p.distance_to(c) < 7.0:
			return false
	for po in ex.get("pois"):
		if po.p.distance_to(c) < 10.0:
			return false
	for cv in caves:
		if (cv.c as Vector2).distance_to(c) < 30.0:
			return false
	return true


func _torch_light(node: Node3D, at: Vector3) -> void:
	if G.web_mobile() or G.quality() == 0:
		return
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.7, 0.4)
	l.light_energy = 0.9
	l.omni_range = 5.0
	l.shadow_enabled = false
	l.position = at
	node.add_child(l)


## Punkte für die Übersichtskarte der Expedition (expedition.map_points ruft das auf).
func map_points(out: Array) -> void:
	for cv in caves:
		if not bool(cv.done) and (bool(cv.seen) or not ex.has_method("_seen") or ex._seen(cv.p)):
			out.append([cv.p, "chest"])


func _physics_process(dt: float) -> void:
	if not is_instance_valid(ex) or ex.ended or ex.hero == null:
		return
	_t += dt
	if not _anims.is_empty():
		Anim.tick(_anims, _t, dt)
	_msg_t -= dt
	_tick_caves(dt)
	_bed_t -= dt
	if _bed_t <= 0.0:
		_bed_t = 0.25
		_tick_bed()


func _tick_caves(dt: float) -> void:
	if caves.is_empty():
		return
	var h = ex.hero
	var pp: Vector2 = h.pos2()
	var near := -1
	for cv in caves:
		var d: float = pp.distance_to(cv.p)
		if d < 14.0 and not bool(cv.seen):
			cv.seen = true
			if not bool(cv.done):
				P.toast.emit("Eine Höhle! Stell dich in den Eingang, um hineinzugehen.")
		if d > 3.0:
			_armed[int(cv.idx)] = true
		if d < 1.4 and not bool(cv.done) and bool(_armed.get(int(cv.idx), true)):
			near = int(cv.idx)
		if cv.ring != null:
			(cv.ring as MeshInstance3D).visible = not bool(cv.done)
			var pulse := 1.0 + 0.06 * sin(_t * 4.0)
			(cv.ring as MeshInstance3D).scale = Vector3.ONE * (pulse if near != int(cv.idx) else 1.0 + 0.25 * _hold / DM.CAVE_ENTER_HOLD)
	if near < 0 or not h.alive:
		# kurz aus dem Eingang geschubst (Rückstoß, Ausweichrolle): Fortschritt nur langsam verlieren
		_hold = maxf(0.0, _hold - dt * 2.0)
		if _hold <= 0.0:
			_hold_i = -1
		return
	if h.mounted:
		if _msg_t <= 0.0:
			_msg_t = 3.0
			P.toast.emit("Steig ab, um die Höhle zu betreten.")
		return
	if _hold_i != near:
		_hold_i = near
		_hold = 0.0
	_hold += dt
	if _hold >= DM.CAVE_ENTER_HOLD:
		_hold = 0.0
		_armed[near] = false
		enter_cave.call_deferred(near)


## Geht in die Höhle i (auch für Tests).
func enter_cave(i: int) -> void:
	if i < 0 or i >= caves.size() or bool(caves[i].done) or G.main == null:
		return
	var cv: Dictionary = caves[i]
	var cave = load("res://src/cave_world.gd").new()
	cave.init(ex, self, i, String(cv.theme), int(cv.seed))
	cave.swap_in()


## Aus cave_world.gd: Höhle verlassen (fertig erkundet oder nicht).
func cave_left(i: int, finished: bool) -> void:
	if i >= 0 and i < caves.size() and finished:
		caves[i].done = true
		var nd = caves[i].n
		if nd != null:
			for gi in (nd as Node3D).find_children("*", "OmniLight3D", true, false):
				(gi as OmniLight3D).light_energy = 0.4


# ================================================================= Ladefläche
func _setup_bed() -> void:
	var h = ex.hero
	if h == null or String(h.veh_key) != "pickup" or h.veh_node == null:
		return
	var lv := 0
	if P.d.vehicles.has("pickup"):
		lv = int(P.d.vehicles.pickup.get("bed", 0))
	bed_cap = DM.BED_CAP * (1.0 + 0.15 * lv)
	var tn: Node3D = Models.find(h.veh_node, "turret")
	var base := tn.position if tn != null else Vector3(0, 1.32, -1.0)
	if Models.has_glb("v_pickup_rack"):
		_rack = Models.glb("v_pickup_rack")
		_rack.position = base
		h.veh_node.add_child(_rack)
	_cargo_l = Node3D.new()
	_cargo_l.name = "BedL"
	_cargo_l.position = base + Vector3(-0.58, 0.02, 0)
	h.veh_node.add_child(_cargo_l)
	_cargo_r = Node3D.new()
	_cargo_r.name = "BedR"
	_cargo_r.position = base + Vector3(0.58, 0.02, 0)
	h.veh_node.add_child(_cargo_r)


func has_bed() -> bool:
	return bed_cap > 0.0 and is_instance_valid(ex) and ex.hero != null and ex.hero.veh_node != null


func _truck_pos():
	var h = ex.hero
	if h.mounted:
		return h.pos2()
	var vp = h.vehicle_pos()
	if vp == null:
		return null
	return Vector2(vp.x, vp.z)


func _recalc_bed() -> void:
	bed_weight = 0.0
	for r in bed:
		bed_weight += float(bed[r]) * float(ex.unit_weight(String(r)))


func bed_room(r: String) -> float:
	var w: float = ex.unit_weight(r)
	return 1.0e9 if w <= 0.0 else maxf(0.0, (bed_cap - bed_weight) / w)


func _tick_bed() -> void:
	if not has_bed():
		return
	var h = ex.hero
	# Fahrzeug kaputt: Ladung fällt als Haufen herab
	if float(h.veh_hp) <= 0.0:
		if not _veh_dead:
			_veh_dead = true
			_drop_bed()
		return
	var tp = _truck_pos()
	if tp == null:
		return
	var pp: Vector2 = h.pos2()
	# Umladen: Held zu Fuß neben dem Fahrzeug, Rucksack mindestens zu einem Viertel voll
	if not h.mounted and h.alive and pp.distance_to(tp) < DM.BED_REACH and float(ex.weight) >= float(ex.cap) * 0.25:
		load_bed()
	# Abladen am Depot der Außenbasis (auch beim Heimkehren mit dem Fahrzeug an der Außenbasis)
	var op = ex.get("outpost")
	if op != null and op.nodes.get("depot") != null and not bed.is_empty():
		if (tp as Vector2).distance_to(op.depot_pos) < DM.BED_DEPOT or (h.mounted and (tp as Vector2).distance_to(op.C) < 14.0):
			unload_bed()
	_update_cargo()
	_update_pill()


## Anzeige im Kampfbild: kleine Tafel unter der Übersichtskarte (nur mit Ladung).
func _update_pill() -> void:
	var hud = G.main.hud if G.main != null else null
	if hud == null:
		return
	if _bed_pill == null or not is_instance_valid(_bed_pill):
		var UI = load("res://src/ui.gd")
		_bed_label = UI.label("", 21, UI.GOLD)
		var p: PanelContainer = UI.pill(UI.hbox(8, [UI.vehicle_pic("pickup", 40.0), _bed_label]), 12, 4)
		UI.ignore_mouse(p)
		var m := MarginContainer.new()
		m.set_anchors_preset(Control.PRESET_FULL_RECT)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_theme_constant_override("margin_right", 24)
		m.add_theme_constant_override("margin_top", 352)
		p.size_flags_horizontal = Control.SIZE_SHRINK_END
		p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		m.add_child(p)
		hud.root.add_child(m)
		_bed_pill = m
	_bed_pill.visible = G.main.world == ex and bed_weight > 0.5
	_bed_label.text = bed_text()


func _exit_tree() -> void:
	if _bed_pill != null and is_instance_valid(_bed_pill):
		_bed_pill.visible = false                   # Höhle oder Ende der Expedition


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _bed_pill != null and is_instance_valid(_bed_pill):
		_bed_pill.queue_free()


## Rucksack auf die Ladefläche umladen (so viel passt). Rückgabe: umgeladenes Gewicht.
func load_bed() -> float:
	if not has_bed():
		return 0.0
	var moved := 0.0
	var any_full := false
	var vp = ex.hero.vehicle_pos()
	var to3: Vector3 = (vp as Vector3) + Vector3(0, 1.5, 0) if vp != null else ex.hero.global_position + Vector3(0, 1.5, 0)
	for r in ex.loot.keys():
		var rk := String(r)
		if rk == "coins":
			continue
		var have := float(ex.loot[r])
		var take := minf(have, bed_room(rk))
		if take < 1.0:
			any_full = any_full or have >= 1.0
			continue
		bed[rk] = float(bed.get(rk, 0.0)) + take
		bed_weight += take * float(ex.unit_weight(rk))
		ex.loot[r] = have - take
		if float(ex.loot[r]) < 0.5:
			ex.loot.erase(r)
		moved += take * float(ex.unit_weight(rk))
		if ex.has_method("_fly_to") and ex.pack != null:
			ex._fly_to(ex.pack.load_point(), to3, rk)
	if moved > 0.0:
		_recalc_bed()
		ex._recalc_weight()
		Sfx.play("bed_load", -4.0)
		ex.fx.float_text(to3 + Vector3(0, 1.0, 0), "Auf die Ladefläche!", D.C_GOLD)
		ex.state_changed.emit()
	elif any_full and _msg_t <= 0.0:
		_msg_t = 4.0
		P.toast.emit("Die Ladefläche ist voll – fahr zum Depot der Außenbasis.")
	return moved


## Ladefläche ins Depot der Außenbasis abladen.
func unload_bed() -> void:
	if bed.is_empty():
		return
	var op = ex.outpost
	for r in bed.keys():
		ex.depot[r] = float(ex.depot.get(r, 0.0)) + float(bed[r])
		if ex.has_method("_fly_to"):
			var tp = _truck_pos()
			var from: Vector3 = Vector3(tp.x, 1.6, tp.y) if tp != null else ex.hero.global_position
			ex._fly_to(from, Vector3(op.depot_pos.x, 0.8, op.depot_pos.y), String(r))
	bed.clear()
	_recalc_bed()
	ex.loads = int(ex.loads) + 1
	Sfx.play("bed_unload", -3.0)
	ex.fx.float_text(Vector3(op.depot_pos.x, 3.2, op.depot_pos.y), "Ladefläche abgeladen!", D.C_GOLD)
	ex.state_changed.emit()


func _drop_bed() -> void:
	if bed.is_empty() or ex.pack == null:
		return
	for r in bed.keys():
		ex.loot[r] = float(ex.loot.get(r, 0.0)) + float(bed[r])
		ex.pack.drop(String(r), float(bed[r]))
	bed.clear()
	_recalc_bed()
	ex._recalc_weight()
	P.toast.emit("Die Pritsche ist kaputt – die Ladung liegt am Boden.")


func _update_cargo() -> void:
	if _cargo_l == null:
		return
	var counts := CD.cargo_counts(bed, bed_weight, bed_cap, CD.slot_count(DM.BED_SLOTS) * 2, ex.unit_weight)
	var sig := str(counts)
	if sig == _cargo_sig:
		return
	_cargo_sig = sig
	var lc := {}
	var rc := {}
	var i := 0
	for r in counts:
		for k in int(counts[r]):
			var side: Dictionary = lc if i % 2 == 0 else rc
			side[r] = int(side.get(r, 0)) + 1
			i += 1
	CD.build_cargo(_cargo_l, lc, DM.BED_SLOTS)
	CD.build_cargo(_cargo_r, rc, DM.BED_SLOTS)


## Anzeige im Kampfbild (hud): Text zur Ladefläche oder "".
func bed_text() -> String:
	if not has_bed():
		return ""
	return "Ladefläche: %d %%" % int(bed_weight / maxf(bed_cap, 1.0) * 100.0)
