extends RefCounted
## Prüfungen für Paket 6, Teil Verteidigung: Aufbau der Turm-Modelle, Ausbau-Aussehen (lvN_/lvmaxN_),
## Zustands-Objekte (dmgN_/fillN_), Mauer-Meshes, Baugerüst, Schadensstufen im Spiel.
## Aufruf aus tests.gd (--selftest).

const D = preload("res://src/data.gd")
const Models = preload("res://src/models.gd")

const TOWERS := ["mg", "watch", "cannon", "flame", "mortar", "tesla", "rocket", "ice", "aa", "mini"]

var T: Node                      # tests.gd (für _check und _wait)


func _init(tests: Node) -> void:
	T = tests


func run() -> void:
	_models()
	_walls()
	await _world()


func _is_under(n: Node, anc: Node) -> bool:
	var p := n
	while p != null:
		if p == anc:
			return true
		p = p.get_parent()
	return false


func _tris(m: Mesh) -> int:
	var n := 0
	for i in m.get_surface_count():
		var arr := m.surface_get_arrays(i)
		var idx = arr[Mesh.ARRAY_INDEX]
		n += (idx.size() if idx != null and idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return n


func _count_tris(n: Node) -> int:
	var t := 0
	if n is MeshInstance3D and n.mesh != null:
		t += _tris(n.mesh)
	for c in n.get_children():
		t += _count_tris(c)
	return t


# ---------------------------------------------------------------- Modelle
func _models() -> void:
	# Aufbau, den tower.gd erwartet: base, head, pitch (unter head), muzzle (unter pitch)
	for key in TOWERS:
		var nm: String = "t_" + key
		T._check(Models.has_glb(nm), "Turm-Modell %s vorhanden" % nm)
		if not Models.has_glb(nm):
			continue
		var sc := Models.glb(nm, 1)
		var base := Models.find(sc, "base")
		var head := Models.find(sc, "head")
		var pitch := Models.find(sc, "pitch")
		var mz := Models.find(sc, "muzzle")
		T._check(base != null and head != null and pitch != null and mz != null, "%s hat base, head, pitch, muzzle" % nm)
		if head != null and pitch != null and mz != null:
			T._check(_is_under(pitch, head) and _is_under(mz, pitch) and not _is_under(head, base), "%s: pitch hängt an head, muzzle an pitch" % nm)
		T._check(_count_tris(sc) <= 6000, "%s höchstens 6000 Dreiecke (%d)" % [nm, _count_tris(sc)])
		if key != "mini":
			T._check(Models.find(sc, "work_1") != null and Models.find(sc, "fx_smoke_dmg") != null, "%s hat work_1 und fx_smoke_dmg" % nm)
			# Ausbau-Aussehen: lvmax3 nur bis Stufe 3, lv4 ab 4, lvmax6 bis 6, lv7 ab 7
			for lv in [1, 3, 4, 6, 7, 10]:
				var m := Models.glb(nm, lv)
				var ok := true
				for want in [["lvmax3_", lv <= 3], ["lv4_", lv >= 4], ["lvmax6_", lv <= 6], ["lv7_", lv >= 7]]:
					var found := 0
					for n in m.find_children(String(want[0]) + "*", "Node3D", true, false):
						found += 1
						if n.visible != bool(want[1]):
							ok = false
					if found == 0:
						ok = false
				T._check(ok, "%s Stufe %d: Ausbau-Objekte richtig geschaltet" % [nm, lv])
				m.free()
			# Schaden: anfangs verborgen, stufenweise einschaltbar
			var st := Models.states(sc)
			T._check(Models.state_max(st, "dmg") == 2, "%s hat dmg1_ und dmg2_" % nm)
			var hidden := true
			for lvl in st.get("dmg", {}):
				for n in st.dmg[lvl]:
					hidden = hidden and not n.visible
			T._check(hidden, "%s: Schadens-Objekte anfangs verborgen" % nm)
			Models.set_state(st, "dmg", 1)
			T._check(st.dmg[1][0].visible and not st.dmg[2][0].visible, "%s: Schadensstufe 1 zeigt nur dmg1_" % nm)
			Models.set_state(st, "dmg", 2)
			T._check(st.dmg[1][0].visible and st.dmg[2][0].visible, "%s: Schadensstufe 2 zeigt dmg1_ und dmg2_" % nm)
			Models.set_state(st, "dmg", 0)
			T._check(not st.dmg[1][0].visible and not st.dmg[2][0].visible, "%s: heil = keine Schadens-Objekte" % nm)
		sc.free()
	# Zustandsgruppen allgemein (auch fillN_), an einem künstlichen Modell
	var root := Node3D.new()
	for nm in ["body", "fill1_a", "fill2_a", "fill3_a", "fill4_a", "dmg1_x", "dmg2_x", "lvmax3_old", "lv4_new", "filler", "dmgx_no"]:
		var c := Node3D.new()
		c.name = nm
		root.add_child(c)
	Models._fix(root, 5)
	T._check(not root.get_node("lvmax3_old").visible and root.get_node("lv4_new").visible, "lvmax3_ verschwindet ab Stufe 4, lv4_ erscheint")
	T._check(root.get_node("filler").visible and root.get_node("dmgx_no").visible and root.get_node("body").visible, "ähnliche Namen ohne Stufe bleiben unberührt")
	var st2 := Models.states(root)
	T._check(Models.state_max(st2, "fill") == 4 and Models.state_max(st2, "dmg") == 2, "Zustandsgruppen werden gefunden")
	T._check(not root.get_node("fill1_a").visible, "Füllstand anfangs verborgen")
	Models.set_state(st2, "fill", 3)
	T._check(root.get_node("fill1_a").visible and root.get_node("fill3_a").visible and not root.get_node("fill4_a").visible, "Füllstand 3 zeigt fill1..3")
	T._check(Models.set_state({}, "dmg", 2) == 0 and Models.states(null).is_empty(), "Modelle ohne Zustands-Objekte laufen weiter")
	root.free()
	# Tore: Aufbau wie bisher, Flaggen bekommen die Spielerfarbe
	for tier in 3:
		var g := Models.glb("b_tor_%d" % tier)
		var ok := true
		for nm in ["body", "door_l", "door_r", "lamp_open_glow", "lamp_closed_glow", "sway_flag", "bubble"]:
			ok = ok and Models.find(g, nm) != null
		T._check(ok, "Tor %d hat body, door_l, door_r, Lampen, sway_flag, bubble" % tier)
		var fl := Models.find(g, "sway_flag") as MeshInstance3D
		T._check(fl != null and fl.material_override == load("res://src/mk.gd").mat_flag(), "Tor %d: Fahne in Spielerfarbe" % tier)
		var dl := Models.find(g, "door_l")
		var dr := Models.find(g, "door_r")
		if dl != null and dr != null:
			T._check(dr.position.x - dl.position.x >= 2.6, "Tor %d: Durchfahrt mindestens 2,6 m (%.2f)" % [tier, dr.position.x - dl.position.x])
		g.free()
	# Gerüste, Statue, Mine, Flagge
	for sz in [[2, 2], [3, 3], [4, 4], [3, 2], [4, 3], [2, 1]]:
		var nm2 := "b_scaffold_%dx%d" % sz
		T._check(Models.scaffold_name(int(sz[0]), int(sz[1])) == nm2, "Gerüst %s vorhanden" % nm2)
		if Models.has_glb(nm2):
			var sc2 := Models.glb(nm2)
			T._check(Models.find(sc2, "body") != null and not sc2.find_children("sway_tarp*", "Node3D", true, false).is_empty(), "%s hat body und sway_tarp" % nm2)
			sc2.free()
	T._check(Models.scaffold_name(2, 3) == "b_scaffold_3x2", "gedrehte Grundfläche findet das passende Gerüst")
	var stt := Models.glb("b_statue")
	T._check(Models.find(stt, "statue_slot") != null and Models.find(stt, "statue_default") != null, "Statue hat statue_slot und statue_default")
	stt.free()
	var mn := Models.glb("b_mine")
	T._check(Models.find(mn, "lamp_glow") != null, "Mine hat das Blinklicht lamp_glow")
	mn.free()
	var fg := Models.glb("b_flagge")
	T._check(Models.find(fg, "sway_flag") != null, "Flagge: Tuch heißt sway_flag")
	fg.free()


# ---------------------------------------------------------------- Mauer-Meshes
func _walls() -> void:
	for tier in 3:
		var post := Models.wall_post(tier)
		var link := Models.wall_link(tier)
		var pb := post.get_aabb()
		var lb := link.get_aabb()
		T._check(_tris(post) <= 500 and _tris(link) <= 500, "Mauer %d: je höchstens 500 Dreiecke (%d / %d)" % [tier, _tris(post), _tris(link)])
		T._check(absf(lb.position.x + 1.0) < 0.03 and absf(lb.end.x - 1.0) < 0.03, "Mauer %d: Verbindung genau 2 m lang und mittig (%.2f..%.2f)" % [tier, lb.position.x, lb.end.x])
		T._check(absf(pb.get_center().x) < 0.08 and absf(pb.get_center().z) < 0.08 and pb.size.x <= 1.3 and pb.size.z <= 1.3, "Mauer %d: Pfosten steht in der Feldmitte" % tier)
		T._check(lb.size.z <= pb.size.z + 0.02 and lb.end.y <= pb.end.y, "Mauer %d: Pfosten überdeckt das Ende der Verbindung" % tier)
		T._check(lb.position.y > -0.02 and pb.position.y > -0.02, "Mauer %d: nichts ragt in den Boden" % tier)
	T._check(Models.wall_site().get_aabb().size.x <= 2.1 and _tris(Models.wall_site()) <= 500, "Mauer-Baustelle passt in ein Feld")


# ---------------------------------------------------------------- im Spiel
func _world() -> void:
	P.new_game()
	P.no_save = true
	P.add_many({"coins": 9000, "wood": 3000, "stone": 3000})
	var c := int(D.GRID_MAX / 2)
	var mg := P.place("mg", c + 6, c + 2)
	var mg2 := P.place("mg", c + 9, c + 2)
	T._check(not mg.is_empty() and not mg2.is_empty(), "zwei MG-Türme gesetzt")
	if mg.is_empty() or mg2.is_empty():
		return
	P.finish_now(int(mg2.id))
	G.main.goto_base()
	var w = G.main.world
	await T._wait(0.3)
	# Baustelle: Gerüst-Modell, Gebäude wächst mit dem Fortschritt
	var s = w.nodes[int(mg.id)]
	T._check(s.constructing and s._site != null and s._site.get_node_or_null("scaffold") != null, "Turm im Bau: Gerüst steht")
	if s._site != null and s._site.get_node_or_null("scaffold") != null:
		T._check(Models.find(s._site.get_node("scaffold"), "body") != null and not s._site_anims.is_empty(), "Gerüst ist das Blender-Modell mit Planen")
	T._check(not s._clip.is_empty() and s._model_h > 1.0, "erster Bau: Rohbau-Materialien gesetzt")
	if not s._clip.is_empty():
		s._update_clip(0.0)
		var y0: float = s._clip[0].get_shader_parameter("clip_y")
		s._update_clip(1.0)
		var y1: float = s._clip[0].get_shader_parameter("clip_y")
		T._check(y1 > y0 + 1.0 and y1 >= s._model_h * 0.99, "Baufortschritt hebt die sichtbare Höhe (%.1f -> %.1f m)" % [y0, y1])
	T._check(s.tower != null and not s.tower.active, "Turm im Bau schießt nicht")
	# Fertiger Turm: Schadensstufen nach Leben
	var t = w.nodes[int(mg2.id)]
	T._check(not t.constructing and t._site == null and t._clip.is_empty(), "fertiger Turm: kein Gerüst, kein Rohbau")
	T._check(Models.state_max(t._states, "dmg") == 2 and t.dmg_stage == 0, "fertiger Turm ist heil")
	var d1: Node3D = t._states.dmg[1][0]
	var d2: Node3D = t._states.dmg[2][0]
	w.barrier_t = 0.0
	t.hp = t.max_hp * 0.55
	t._update_damage()
	T._check(t.dmg_stage == 1 and d1.visible and not d2.visible, "unter 60 % Leben: dmg1_ sichtbar")
	t.hp = t.max_hp * 0.25
	t._update_damage()
	T._check(t.dmg_stage == 2 and d2.visible and t._dmg_smoke != null and t._dmg_smoke.emitting, "unter 30 % Leben: dmg2_ sichtbar, Rauch steigt auf")
	t.repair(1.0)
	T._check(t.dmg_stage == 0 and not d1.visible and not d2.visible and not t._dmg_smoke.emitting, "repariert: Schaden und Rauch verschwinden")
	t.hp = t.max_hp * 0.2
	t._update_damage()
	t._destroy()
	T._check(not t.alive and t.dmg_stage == 0 and not t.model.visible, "zerstört: Trümmerhaufen statt Modell")
	t.restore()
	T._check(t.alive and t.model.visible and t.dmg_stage == 0 and not d2.visible, "wiederhergestellt: heil")
	# Hülsenauswurf und bewegte Teile
	T._check(t.tower._shell != null and t.tower.muzzles.size() == 2, "MG-Turm: Hülsenauswurf und zwei Mündungen")
	# Statue: Figur des gewählten Helden auf dem Sockel
	P.bunker().level = 4
	P.add_many({"coins": 9000, "stone": 3000})
	var stb := P.place("statue", c - 9, c + 5)
	if not stb.is_empty():
		P.finish_now(int(stb.id))
		w._sync()
		await T._wait(0.2)
		var sn = w.nodes[int(stb.id)]
		T._check(sn._slot != null, "Statue: statue_slot gefunden")
		var dflt := Models.find(sn.model, "statue_default")
		T._check(sn._slot_node != null and dflt != null and not dflt.visible, "Statue zeigt den gewählten Helden (%s) statt der neutralen Figur" % String(P.d.hero_sel))
	else:
		T._check(false, "Statue ließ sich nicht setzen")
	# Mauern neben dem Tor: halbes Verbindungsstück schließt die Lücke
	var gate = null
	for id in w.nodes:
		if w.nodes[id].gate:
			gate = w.nodes[id]
	if gate != null:
		var along_x: bool = gate.size.x >= gate.size.y
		var gx := int(gate.b.x)
		var gy := int(gate.b.y)
		var cell := Vector2i(gx - 1, gy) if along_x else Vector2i(gx, gy - 1)
		var had := false
		for b in P.d.buildings:
			if b.key == "wall" and int(b.x) == cell.x and int(b.y) == cell.y:
				had = true
		if had:
			var half: int = w.gate_links
			T._check(half >= 1, "Mauer neben dem Tor: halbes Verbindungsstück bis zur Torkante (%d)" % half)
