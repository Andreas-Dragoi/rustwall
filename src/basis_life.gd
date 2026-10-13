extends Node3D
## V6 Paket B: kleine Dinge der Hauptbasis (Kapitel 4.1 / 7.2), ein Kind von base_world.
##  - Mauer-Schäden sichtbar: Risse, Ruß und Trümmer (Blender-Modelle wall_dmg_<Bauart>_<1|2>) über beschädigten Mauerstücken,
##    auch während der Flut; nach der Flut behalten Mauern ihren Schaden (b.dmg), „Alle reparieren“ macht alles heil.
##  - Glitzer über Hindernissen mit seltenem Fund, Funkeln beim Fund.
##  - Wasser: Spritzer und Ring, wenn der Held durch Bach-Ufer, Tümpel, Brandung oder (bei Regen) Pfützen läuft.
##  - Verletzte Bewohner: Verband am Kopf (Modell c_bandage), langsamer, gehen zum Verarzten in den Bunker.

const D = preload("res://src/data.gd")
const DB = preload("res://src/data_basis.gd")
const Models = preload("res://src/models.gd")
const MK = preload("res://src/mk.gd")
const Nature = preload("res://src/base_nature.gd")
const BState = preload("res://src/basis_state.gd")
const Research = preload("res://src/research.gd")

var w                                  # base_world
var _mm: Array = []                    # [Bauart][Stufe 0|1] -> MultiMesh
var _dmg_sig := ""
var _t := 0.0
var _glints := {}                      # Gebäude-ID -> CPUParticles3D
var _hero_ref = null
var _step_n := 0
var splashes := 0                      # (Test) so oft hat es gespritzt
var bandages := 0                      # (Test) sichtbare Verbände
var walls_damaged := 0                 # (Test) Mauerstücke mit sichtbarem Schaden
var repaired := 0                      # (Test) zuletzt reparierte Teile


func setup(world) -> void:
	w = world
	name = "BasisLeben"
	for tier in 3:
		var row: Array = []
		for st in 2:
			var nm := "wall_dmg_%d_%d" % [tier, st + 1]
			if not Models.has_glb(nm):
				row.append(null)
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = Models.glb_mesh(nm)
			var mi := MultiMeshInstance3D.new()
			mi.multimesh = mm
			mi.material_override = MK.mat_lin()
			mi.custom_aabb = AABB(Vector3(-50, -1, -50), Vector3(100, 8, 100))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			row.append(mm)
		_mm.append(row)
	P.building_done.connect(_on_done)
	if G.arg("b6") != "":
		preload("res://src/basis_shots.gd").run(w)          # nur für Bildschirmfotos


func _exit_tree() -> void:
	if P.building_done.is_connected(_on_done):
		P.building_done.disconnect(_on_done)


## Fertig verbesserte Mauer: der Schaden ist mit dem Ausbau weg.
func _on_done(id: int) -> void:
	var b := P.get_building(id)
	if not b.is_empty() and (String(b.key) == "wall" or String(b.key) == "tor") and b.has("dmg"):
		b.erase("dmg")
		P.mark()


func _process(dt: float) -> void:
	if w == null:
		return
	_t -= dt
	if _t <= 0.0:
		_t = 0.5
		update_wall_damage()
		if w.mode == "peace":
			_update_glints()
			_update_injured()
		_hook_hero()
	if not BState.find_events.is_empty():
		var ev: Array = BState.find_events.pop_front()
		var c: Vector2i = ev[0]
		var p: Vector2 = w.cell_min(c.x, c.y) + Vector2(1, 1)
		if w.fx != null:
			w.fx.confetti(Vector3(p.x, 0.8, p.y), 3)
			w.fx.ring(Vector3(p.x, 0, p.y), 2.2, Color(1.0, 0.9, 0.4), 0.6)


# ---------------------------------------------------------------- Mauer-Schäden
func _stage(seg) -> int:
	if not seg.alive or seg.site:
		return -1
	var k: float = seg.hp / maxf(1.0, seg.max_hp)
	return 1 if k < 0.3 else (0 if k < 0.6 else -1)


func update_wall_damage() -> void:
	if _mm.is_empty():
		return
	var lists: Array = [[[], []], [[], []], [[], []]]
	var sig := ""
	var n := 0
	for seg in w.walls:
		var st := _stage(seg)
		if st < 0:
			continue
		n += 1
		var yaw := float((seg.x * 7 + seg.y * 13) % 4) * PI * 0.5
		lists[seg.tier][st].append(Transform3D(Basis(Vector3.UP, yaw), Vector3(seg.mid.x, 0, seg.mid.y)))
		sig += "%d%d%d," % [seg.x, seg.y, st]
	walls_damaged = n
	if sig == _dmg_sig:
		return
	_dmg_sig = sig
	for tier in 3:
		for st in 2:
			var mm: MultiMesh = _mm[tier][st]
			if mm == null:
				continue
			var l: Array = lists[tier][st]
			mm.instance_count = l.size()
			for i in l.size():
				mm.set_instance_transform(i, l[i])


## Nach der Flut (base_world.back_to_peace): Schaden der Mauerstücke in den Spielstand (zerstörte stehen als Trümmer).
func store_wall_damage() -> void:
	var by_id := {}
	for seg in w.walls:
		by_id[int(seg.id)] = seg
	for b in P.d.buildings:
		if String(b.key) != "wall" or not by_id.has(int(b.id)):
			continue
		var seg = by_id[int(b.id)]
		if seg.site:
			continue
		var miss: float = 1.0 - DB.WALL_RUBBLE if not seg.alive else 1.0 - seg.hp / maxf(1.0, seg.max_hp)
		miss = snappedf(clampf(miss, 0.0, 0.95), 0.01)
		if miss > 0.01:
			b["dmg"] = miss
		elif b.has("dmg"):
			b.erase("dmg")
	P.mark()


## „Alle reparieren“: bezahlt und macht Mauern, Tore und Gebäude sofort heil. Rückgabe: "" oder der Grund.
func repair_all() -> String:
	var q := BState.repair_quote()
	if int(q.walls) + int(q.buildings) <= 0:
		return "Nichts zu reparieren"
	if not P.pay(q.cost):
		return P.missing_text(q.cost)
	var n := 0
	for b in P.d.buildings:
		if b.has("dmg") and not P.is_building(b):
			b.erase("dmg")
			n += 1
	for id in w.nodes:
		var s = w.nodes[id]
		if s != w.bunker_node and s.hp < s.max_hp:
			s.hp = s.max_hp
			s._update_damage()
			if w.fx != null and n < 40:
				w.fx.puff(Vector3(s.mid.x, 1.5, s.mid.y), Color(1.0, 0.9, 0.6), 6, 0.8)
	var k := 0
	for seg in w.walls:
		if seg.hp < seg.max_hp * (0.25 if seg.site else 1.0) - 0.5:
			if w.fx != null and k < 30:
				w.fx.puff(Vector3(seg.mid.x, 1.2, seg.mid.y), Color(0.9, 0.85, 0.7), 5, 0.7)
			k += 1
	repaired = n
	Sfx.play("repair_all", -4.0)
	P.count_up("repairs", n)
	P.mark()
	P.buildings_changed.emit()
	update_wall_damage()
	return ""


# ---------------------------------------------------------------- Funde: Glitzer
func _update_glints() -> void:
	var seen := {}
	for id in w.nodes:
		var s = w.nodes[id]
		if not s.obstacle or s.b.is_empty() or String(s.b.get("find", "")) == "" or bool(s.b.get("clear", false)):
			continue
		seen[id] = true
		if not _glints.has(id) or not is_instance_valid(_glints[id]):
			_glints[id] = _make_glint(s)
	for id in _glints.keys():
		if not seen.has(id):
			if is_instance_valid(_glints[id]):
				_glints[id].queue_free()
			_glints.erase(id)


func _make_glint(s: Node3D) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.42, 0.42)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	if ResourceLoader.exists("res://icons/ui_star.png"):
		m.albedo_texture = load("res://icons/ui_star.png")      # kleine goldene Sterne funkeln
	qm.material = m
	p.mesh = qm
	p.amount = 7
	p.lifetime = 1.3
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.8
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3(0, 0.5, 0)
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.35
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.1
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 1.0, 0.8, 0.0))
	g.add_point(0.25, Color(1.0, 0.95, 0.6, 1.0))
	g.set_color(g.get_point_count() - 1, Color(1.0, 0.85, 0.3, 0.0))
	p.color_ramp = g
	p.position = Vector3(0, 1.1, 0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.add_child(p)
	return p


func glint_count() -> int:
	return _glints.size()


# ---------------------------------------------------------------- Wasser
func _hook_hero() -> void:
	var hr = w.hero
	if hr == null or hr == _hero_ref or hr.get("body") == null:
		return
	_hero_ref = hr
	if hr.body.has_signal("footstep"):
		hr.body.footstep.connect(_on_step)


## Nass unter den Füßen? 2 = Tümpel/Bach/Brandung, 1 = Pfütze bei Regen, 0 = trocken.
func wet_at(p: Vector2) -> int:
	if Nature.in_pond(p, 0.2):
		return 2
	if Nature.in_brook(p, 2.7) and not (absf(p.y - Nature.BRIDGE.y) < 3.0 and absf(p.x - Nature.BRIDGE.x) < 4.0):
		return 2
	if Nature.in_sea(p, -2.6):
		return 2
	if w.weather != null and float(w.weather.wet) > 0.55 and w.nature != null and w.nature.on_path(p):
		return 1
	return 0


func _on_step(_left: bool) -> void:
	if w == null or w.hero == null or not w.hero.alive:
		return
	var p: Vector2 = w.hero.pos2()
	var k := wet_at(p)
	if k == 0:
		return
	_step_n += 1
	if k == 1 and _step_n % 2 == 1:
		return
	splash(p, k == 2)


func splash(p: Vector2, deep: bool) -> void:
	splashes += 1
	if w.fx != null:
		w.fx.puff(Vector3(p.x, 0.15, p.y), Color(0.8, 0.93, 1.0, 0.95), 12 if deep else 6, 1.0 if deep else 0.6)
		w.fx.ring(Vector3(p.x, 0, p.y), 1.1 if deep else 0.7, Color(0.85, 0.95, 1.0, 0.7), 0.45)
	Sfx.play_at("water_step", Vector3(p.x, 0, p.y), -9.0 if deep else -14.0, 1.0, 0.15)


# ---------------------------------------------------------------- Verletzte Bewohner
func _update_injured() -> void:
	var nb = w.npc_board
	if nb == null:
		return
	var inj := BState.injured_now()
	var n := 0
	for npc in nb.npcs:
		var want: bool = npc.hero_key == "" and inj.has(String(npc.name))
		if want != bool(npc.injured):
			npc.injured = want
			_bandage(npc, want)
		if want:
			n += 1
	bandages = n


func _bandage(npc, on: bool) -> void:
	var h: Node3D = npc.h
	var old := h.find_child("Verband", true, false)
	if not on:
		if old != null:
			old.queue_free()
		return
	if old != null or not Models.has_glb("c_bandage"):
		return
	var sk: Skeleton3D = h.get("skel")
	if sk == null or sk.find_bone("head") < 0:
		return
	var ba := BoneAttachment3D.new()
	ba.name = "Verband"
	ba.bone_name = "head"
	sk.add_child(ba)
	var m := Models.glb("c_bandage")
	ba.add_child(m)


## Aus npc_board._next: ein Verletzter geht ab und zu in den Bunker zum Verarzten.
func care_task(board, npc) -> Dictionary:
	var inj: Dictionary = P.d.get("injured", {})
	var nm := String(npc.name)
	if not inj.has(nm):
		return {}
	if P.now() - float(inj[nm].get("care", 0.0)) < DB.INJURY_CARE_GAP:
		return {}
	var door: Vector2 = board._door("bunker")
	return {"kind": "care", "steps": [
		{"at": door, "face": door + Vector2(0, -2), "clip": "sit", "dur": 6.0, "text": "Wird im Bunker verarztet", "care": true}]}
