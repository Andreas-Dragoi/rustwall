extends RefCounted
## Alle Modelle außer Figuren und Türmen: Gebäude, Mauern, Kulissen, Fahrzeuge, Kisten.
## Stil nach dem Referenzbild: gedrungene Formen, abgeschrägte Kanten, kräftige Farben,
## warm leuchtende Fenster. Jedes Modell wird zu wenigen Meshes verschmolzen.

const D = preload("res://src/data.gd")
const MK = preload("res://src/mk.gd")

const C_GLOW := Color(1.0, 0.82, 0.3)


# ================================================================= Modelle aus Blender (models/*.glb)
static var _scenes := {}
static var _missing := {}


static func has_glb(name: String) -> bool:
	if _scenes.has(name):
		return true
	if _missing.has(name):
		return false
	var ok := ResourceLoader.exists("res://models/%s.glb" % name)
	if not ok:
		_missing[name] = true
	return ok


static func _scene(name: String) -> PackedScene:
	if not _scenes.has(name):
		_scenes[name] = load("res://models/%s.glb" % name)
	return _scenes[name]


## Instanz eines Blender-Modells mit den Spiel-Materialien. level blendet Ausbauteile ein:
## Objekte mit Namen "lvN_..." sind erst ab Stufe N sichtbar.
static func glb(name: String, level := 99) -> Node3D:
	var n: Node3D = _scene(name).instantiate()
	_fix(n, level)
	return n


static func _fix(n: Node, level: int) -> void:
	var nm := String(n.name)
	if nm.begins_with("lvmax") and n is Node3D:
		# lvmaxN_*: nur bis Stufe N sichtbar (Teile, die ein späterer Ausbau ersetzt)
		var mx := nm.substr(5).split("_")[0]
		if mx.is_valid_int() and level > int(mx):
			n.visible = false
	elif nm.begins_with("lv") and n is Node3D:
		var num := nm.substr(2).split("_")[0]
		if num.is_valid_int() and level < int(num):
			n.visible = false
	elif n is Node3D and not _state_key(nm).is_empty():
		n.visible = false              # dmgN_* / fillN_*: Zustands-Objekte, schaltet structure.gd über set_state()
	if n is MeshInstance3D:
		var glow := nm.contains("_glow")
		var flag: bool = nm.begins_with("sway_flag") or nm.contains("banner")
		n.material_override = MK.mat_glow() if glow else (MK.mat_flag() if flag else MK.mat_lin())
		if glow:
			n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_fix(c, level)


## Mesh eines Objekts aus einem Blender-Modell (für MultiMesh). node = "" nimmt das erste Mesh.
static func glb_mesh(name: String, node := "") -> Mesh:
	var n: Node = _scene(name).instantiate()
	var mi := _find_mesh(n, node)
	var m: Mesh = mi.mesh if mi != null else null
	n.free()
	return m


static func _find_mesh(n: Node, node: String) -> MeshInstance3D:
	if n is MeshInstance3D and (node == "" or String(n.name) == node):
		return n
	for c in n.get_children():
		var r := _find_mesh(c, node)
		if r != null:
			return r
	return null


static func find(n: Node, node: String) -> Node3D:
	if String(n.name) == node:
		return n as Node3D
	for c in n.get_children():
		var r := find(c, node)
		if r != null:
			return r
	return null


# ----------------------------------------------------------------- Zustands-Objekte (Schaden, Füllstand)
## Zerlegt einen Objektnamen wie "dmg2_soot" oder "fill3_crates" in [Gruppe, Stufe]; sonst leer.
static func _state_key(nm: String) -> Array:
	for pre in ["dmg", "fill"]:
		if nm.begins_with(pre):
			var cut := nm.find("_")
			if cut > pre.length():
				var num := nm.substr(pre.length(), cut - pre.length())
				if num.is_valid_int():
					return [pre, int(num)]
	return []


## Sammelt die Zustands-Objekte eines instanzierten Modells: {"dmg": {1: [Knoten ...], 2: [...]}, "fill": {...}}.
## Modelle ohne solche Objekte liefern ein leeres Verzeichnis.
static func states(root: Node) -> Dictionary:
	var out := {}
	if root != null:
		_collect_states(root, out)
	return out


static func _collect_states(n: Node, out: Dictionary) -> void:
	if n is Node3D:
		var k := _state_key(String(n.name))
		if not k.is_empty():
			if not out.has(k[0]):
				out[k[0]] = {}
			if not out[k[0]].has(k[1]):
				out[k[0]][k[1]] = []
			out[k[0]][k[1]].append(n)
	for c in n.get_children():
		_collect_states(c, out)


## Zeigt alle Objekte einer Gruppe bis einschließlich Stufe upto (0 = keines). Liefert die höchste vorhandene Stufe (0 = Gruppe fehlt).
static func set_state(st: Dictionary, group: String, upto: int) -> int:
	if not st.has(group):
		return 0
	var top := 0
	for lv in st[group]:
		top = maxi(top, int(lv))
		for n in st[group][lv]:
			if is_instance_valid(n):
				n.visible = int(lv) <= upto
	return top


## Höchste Stufe, die ein Modell in einer Gruppe hat (0 = keine).
static func state_max(st: Dictionary, group: String) -> int:
	var top := 0
	if st.has(group):
		for lv in st[group]:
			top = maxi(top, int(lv))
	return top


# ----------------------------------------------------------------- Baustelle
## Name des Gerüst-Modells für eine Grundfläche in Feldern (unverdreht), "" wenn es keines gibt.
static func scaffold_name(w: int, h: int) -> String:
	for nm in ["b_scaffold_%dx%d" % [w, h], "b_scaffold_%dx%d" % [h, w]]:
		if has_glb(nm):
			return nm
	return ""


const _SH_CLIP := """shader_type spatial;
render_mode cull_disabled%s;
uniform float gamma = 1.0;
uniform float boost = 1.15;
uniform float clip_y = 1000.0;
varying float wy;
void vertex() {
	wy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}
void fragment() {
	// Rohbau: alles oberhalb des Baufortschritts fehlt noch; Innenseiten erscheinen dunkel
	if (wy > clip_y) {
		discard;
	}
	ALBEDO = pow(COLOR.rgb, vec3(gamma)) * boost * (FRONT_FACING ? 1.0 : 0.4);
	ROUGHNESS = 0.6;
	SPECULAR = 0.45;
}
"""
static var _clip_shaders := {}


## Ersetzt die Materialien eines Modells durch Rohbau-Materialien, die alles oberhalb von clip_y (Welthöhe) weglassen.
## Rückgabe: Liste der Materialien für clip_set(). Flaggen bleiben bis zur Fertigstellung verborgen.
## Funktioniert gleich im Mobile- und im OpenGL-Renderer (nur discard, keine Instanz-Uniforms).
static func clip_begin(model: Node) -> Array:
	var made := {}
	_clip_walk(model, made)
	return made.values()


static func _clip_walk(n: Node, made: Dictionary) -> void:
	if n is MeshInstance3D:
		var src: Material = n.material_override
		if src == MK.mat_flag():
			n.visible = false
		elif src is ShaderMaterial and (src as ShaderMaterial).get_shader_parameter("gamma") != null:
			if not made.has(src):
				var glow: bool = src == MK.mat_glow()
				if not _clip_shaders.has(glow):
					var sh := Shader.new()
					sh.code = _SH_CLIP % (", unshaded" if glow else "")
					_clip_shaders[glow] = sh
				var m := ShaderMaterial.new()
				m.shader = _clip_shaders[glow]
				m.set_shader_parameter("gamma", (src as ShaderMaterial).get_shader_parameter("gamma"))
				m.set_shader_parameter("boost", (src as ShaderMaterial).get_shader_parameter("boost"))
				made[src] = m
			n.material_override = made[src]
	for c in n.get_children():
		_clip_walk(c, made)


static func clip_set(mats: Array, y: float) -> void:
	for m in mats:
		(m as ShaderMaterial).set_shader_parameter("clip_y", y)


## Höhe eines Modells über seinem Ursprung (aus den Grenzen aller sichtbaren Meshes; das Modell muss im Baum hängen).
static func height(model: Node3D) -> float:
	var top := [0.0]
	_height_walk(model, model.global_transform.affine_inverse(), top)
	return float(top[0])


static func _height_walk(n: Node, inv: Transform3D, top: Array) -> void:
	if n is Node3D and not (n as Node3D).visible:
		return
	if n is MeshInstance3D and n.mesh != null:
		var bb: AABB = (inv * (n as MeshInstance3D).global_transform) * n.mesh.get_aabb()
		top[0] = maxf(top[0], bb.end.y)
	for c in n.get_children():
		_height_walk(c, inv, top)


# ----------------------------------------------------------------- Statue des gewählten Helden
const _SH_STONE := """shader_type spatial;
uniform vec3 stone = vec3(0.47, 0.5, 0.6);
void fragment() {
	// Farbe der Figur wird zu Stein: nur die Helligkeit bleibt
	float g = dot(COLOR.rgb, vec3(0.34));
	ALBEDO = stone * (0.5 + 1.5 * g);
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
}
"""
static var _stone_mat: ShaderMaterial


static func mat_stone() -> ShaderMaterial:
	if _stone_mat == null:
		var sh := Shader.new()
		sh.code = _SH_STONE
		_stone_mat = ShaderMaterial.new()
		_stone_mat.shader = sh
	return _stone_mat


## Unbewegte, steinern eingefärbte Figur eines Helden (für die Heldenstatue). null, wenn die Figur nicht gebaut werden kann.
static func statue_figure(hero_key: String) -> Node3D:
	if not D.HEROES.has(hero_key):
		return null
	var hm: Node3D = load("res://src/humanoid.gd").new()
	if not hm.has_method("build"):
		hm.free()
		return null
	var def: Dictionary = D.HEROES[hero_key]
	hm.build({"helm": def.get("color", D.C_HELM_BLUE), "suit": def.get("suit", D.C_OLIVE), "kind": hero_key, "tier": 0})
	hm.scale = Vector3.ONE * D.CHAR_SCALE
	if hm.has_method("tick"):
		hm.tick(0.016)
	hm.set_process(false)
	hm.set_physics_process(false)
	_petrify(hm)
	return hm


static func _petrify(n: Node) -> void:
	if n is MeshInstance3D:
		n.material_override = mat_stone()
	elif n is AnimationPlayer:
		(n as AnimationPlayer).pause()
	for c in n.get_children():
		_petrify(c)


static func _node(st: SurfaceTool, metal := false) -> Node3D:
	var n := Node3D.new()
	MK.inst(st, n, Vector3.ZERO, metal)
	return n


static func _win(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	MK.glow_box(parent, pos, size, C_GLOW)


static func _sandbags(st: SurfaceTool, a: Vector3, dir: Vector3, n: int, rows := 2) -> void:
	var yaw := atan2(dir.x, dir.z)
	var b := Basis(Vector3.UP, yaw + PI * 0.5)
	for r in rows:
		for i in n - r:
			var p := a + dir * (i * 0.62 + r * 0.31) + Vector3(0, 0.16 + r * 0.28, 0)
			MK.rbox(st, p, Vector3(0.6, 0.3, 0.36), MK.lighten(D.C_SAND, 1.0 - 0.06 * ((i + r) % 2)), 0.1, b)


static func _crate(st: SurfaceTool, p: Vector3, s: float, col: Color, yaw := 0.0) -> void:
	var b := Basis(Vector3.UP, yaw)
	MK.rbox(st, p + Vector3(0, s * 0.5, 0), Vector3(s, s, s), col, 0.05, b)
	MK.box(st, p + Vector3(0, s * 0.5, 0), Vector3(s * 1.02, s * 0.12, s * 1.02), MK.lighten(col, 0.72), b)


static func _barrel(st: SurfaceTool, p: Vector3, col: Color) -> void:
	MK.cyl(st, p, 0.34, 0.34, 0.9, 10, col)
	MK.cyl(st, p + Vector3(0, 0.2, 0), 0.36, 0.36, 0.08, 10, MK.lighten(col, 0.7))
	MK.cyl(st, p + Vector3(0, 0.62, 0), 0.36, 0.36, 0.08, 10, MK.lighten(col, 0.7))


static func _flag(parent: Node3D, pos: Vector3, col: Color, h := 3.0, star := true) -> void:
	var st := MK.begin()
	MK.cyl(st, pos, 0.07, 0.06, h, 6, D.C_WOOD_D)
	MK.rbox(st, pos + Vector3(0.62, h - 0.42, 0), Vector3(1.1, 0.75, 0.06), col, 0.03)
	if star:
		MK.box(st, pos + Vector3(0.62, h - 0.42, 0), Vector3(0.34, 0.34, 0.09), Color.WHITE, Basis(Vector3.BACK, PI * 0.25))
		MK.box(st, pos + Vector3(0.62, h - 0.42, 0), Vector3(0.34, 0.34, 0.09), Color.WHITE)
	MK.inst(st, parent)


# ================================================================= Gebäude
## Liefert das Modell eines Gebäudes (ohne Türme). Vorderseite zeigt nach +Z.
static func building(key: String, level: int, tier := 0) -> Node3D:
	var gname := "b_" + key
	if key == "bunker":
		gname = "b_bunker_%d" % clampi(1 + int((level - 1) / 2), 1, 5)
	elif key == "tor":
		gname = "b_tor_%d" % clampi(level - 1, 0, 2)
	elif D.BUILDINGS.has(key) and D.BUILDINGS[key].has("prop"):
		gname = String(D.BUILDINGS[key].prop)
	if has_glb(gname):
		return glb(gname, level)
	match key:
		"bunker":
			return _bunker(level)
		"saege", "steinbruch", "presse", "raffinerie", "generator":
			return _production(key, level)
		"lager":
			return _lager(level)
		"quartier":
			return _quartier()
		"kistenlager":
			return _kistenlager()
		"werkstatt":
			return _werkstatt()
		"garage":
			return _garage()
		"funkturm":
			return _funkturm()
		"clanhalle":
			return _clanhalle()
		"labor":
			return _labor()
		"schild":
			return _schild()
		"stachel", "kleb", "mine":
			return _trap(key)
		"laterne":
			return lantern()
		"flagge":
			var n := Node3D.new()
			_flag(n, Vector3.ZERO, D.C_FLAG, 3.4)
			return n
		"blumen":
			return _flowerbed()
		"statue":
			return _statue()
	var st := MK.begin()
	MK.rbox(st, Vector3(0, 0.8, 0), Vector3(1.6, 1.6, 1.6), D.C_STONE, 0.12)
	return _node(st)


static func _bunker(level: int) -> Node3D:
	var n := Node3D.new()
	var st := MK.begin()
	var stone := D.C_STONE
	var blue := D.C_BLUE_METAL
	var gold := level >= 10
	if gold:
		blue = Color("E0A82E")
	var stage := 1 + int((level - 1) / 2)          # 1..5 sichtbare Ausbaustufen
	# Sockel und Hauptblock
	MK.rbox(st, Vector3(0, 0.25, 0), Vector3(7.2, 0.5, 6.6), MK.lighten(stone, 0.8), 0.14)
	MK.rbox(st, Vector3(0, 1.6, -0.2), Vector3(6.0, 2.4, 4.8), stone, 0.22)
	# blaue Metallplatten an den Ecken und als Dachkante
	for sx in [-1.0, 1.0]:
		MK.rbox(st, Vector3(2.75 * sx, 1.5, 2.0), Vector3(0.9, 2.5, 0.9), blue, 0.14)
		MK.rbox(st, Vector3(2.75 * sx, 1.5, -2.4), Vector3(0.9, 2.5, 0.9), blue, 0.14)
	MK.rbox(st, Vector3(0, 2.95, -0.2), Vector3(6.4, 0.4, 5.2), blue, 0.14)
	MK.rbox(st, Vector3(0, 3.25, -0.2), Vector3(5.2, 0.3, 4.0), stone, 0.12)
	# Tor mit Rahmen
	MK.rbox(st, Vector3(0, 1.25, 2.3), Vector3(2.4, 2.3, 0.5), blue, 0.12)
	MK.rbox(st, Vector3(-0.52, 1.1, 2.5), Vector3(0.95, 1.9, 0.2), Color("3A4152"), 0.05)
	MK.rbox(st, Vector3(0.52, 1.1, 2.5), Vector3(0.95, 1.9, 0.2), Color("3A4152"), 0.05)
	# Nieten
	for i in 6:
		MK.box(st, Vector3(-2.5 + i, 2.95, 2.42), Vector3(0.16, 0.16, 0.1), MK.lighten(blue, 1.4))
	_sandbags(st, Vector3(1.6, 0, 3.0), Vector3(1, 0, 0), 4)
	_sandbags(st, Vector3(-3.6, 0, 3.0), Vector3(1, 0, 0), 4)
	_crate(st, Vector3(-3.1, 0.5, 1.2), 0.8, D.C_WOOD, 0.3)
	_barrel(st, Vector3(3.2, 0.5, 1.4), D.C_RED)
	if stage >= 2:
		# Anbau links mit olivgrünem Dach
		MK.rbox(st, Vector3(-2.6, 3.9, -1.2), Vector3(2.2, 1.2, 2.2), stone, 0.14)
		MK.rbox(st, Vector3(-2.6, 4.6, -1.2), Vector3(2.5, 0.3, 2.5), D.C_OLIVE, 0.1)
		MK.cyl(st, Vector3(1.6, 3.4, -1.0), 0.08, 0.08, 1.0, 6, D.C_STEEL)
		MK.cyl(st, Vector3(1.6, 4.4, -1.0), 0.75, 0.2, 0.3, 10, Color("DDE3EE"), Basis(Vector3.RIGHT, -0.7))
	if stage >= 3:
		MK.rbox(st, Vector3(1.4, 4.0, -0.4), Vector3(3.0, 1.4, 3.0), stone, 0.16)
		MK.rbox(st, Vector3(1.4, 4.85, -0.4), Vector3(3.4, 0.32, 3.4), blue, 0.12)
	if stage >= 4:
		for sx in [-1.0, 1.0]:
			MK.rbox(st, Vector3(3.1 * sx, 2.3, 2.3), Vector3(1.2, 4.6, 1.2), stone, 0.14)
			MK.rbox(st, Vector3(3.1 * sx, 4.75, 2.3), Vector3(1.5, 0.35, 1.5), blue, 0.1)
	if stage >= 5:
		MK.rbox(st, Vector3(1.4, 5.6, -0.4), Vector3(2.0, 1.2, 2.0), stone, 0.14)
		MK.cone(st, Vector3(1.4, 6.2, -0.4), 1.7, 1.5, 4, blue, Basis(Vector3.UP, PI * 0.25))
	MK.inst(st, n)
	# leuchtende Fenster
	for sx in [-1.0, 1.0]:
		_win(n, Vector3(1.75 * sx, 1.7, 2.22), Vector3(0.6, 0.7, 0.08))
		_win(n, Vector3(3.02 * sx, 1.7, 0.2), Vector3(0.08, 0.7, 0.6))
	_win(n, Vector3(0, 2.62, 2.58), Vector3(1.4, 0.16, 0.06))
	if stage >= 3:
		_win(n, Vector3(1.4, 4.0, 1.12), Vector3(0.7, 0.6, 0.06))
	if stage >= 4:
		for sx in [-1.0, 1.0]:
			_win(n, Vector3(3.1 * sx, 3.6, 2.92), Vector3(0.5, 0.6, 0.06))
	_flag(n, Vector3(-1.2, 3.4, -1.6) if stage < 2 else Vector3(-2.6, 4.7, -1.2), D.C_FLAG, 2.6)
	return n


static func _production(key: String, level: int) -> Node3D:
	var n := Node3D.new()
	var st := MK.begin()
	var big := level >= 4
	match key:
		"saege":
			MK.rbox(st, Vector3(-0.8, 1.1, -0.6), Vector3(3.0, 2.2, 3.2), D.C_WOOD, 0.14)
			MK.rbox(st, Vector3(-0.8, 2.5, -0.6), Vector3(3.5, 0.3, 3.7), D.C_RED, 0.1, Basis(Vector3.BACK, 0.12))
			MK.cyl(st, Vector3(1.9, 0.5, 0.4), 0.9, 0.9, 0.16, 14, Color("D6DBE6"), Basis(Vector3.BACK, PI * 0.5))
			for i in 3 + (2 if big else 0):
				MK.cyl(st, Vector3(1.4 + (i % 2) * 0.5, 0.3 + int(i / 2) * 0.5, -1.9), 0.26, 0.26, 2.2, 8, D.C_WOOD_D, Basis(Vector3.RIGHT, PI * 0.5))
			MK.rbox(st, Vector3(1.6, 0.25, 1.9), Vector3(1.8, 0.5, 1.0), Color("D9B36A"), 0.06)
		"steinbruch":
			MK.ball(st, Vector3(-0.9, 0.9, -0.8), Vector3(2.2, 1.9, 2.0), D.C_ROCK, 3, 0.2, 5, 8)
			MK.ball(st, Vector3(1.4, 0.5, -1.2), Vector3(1.2, 1.0, 1.1), D.C_ROCK_D, 4, 0.2, 4, 7)
			MK.rbox(st, Vector3(1.4, 0.45, 1.3), Vector3(1.6, 0.9, 1.2), D.C_WOOD, 0.1)
			for i in 4:
				MK.rbox(st, Vector3(1.0 + (i % 2) * 0.7, 1.1, 1.0 + int(i / 2) * 0.6), Vector3(0.6, 0.45, 0.5), D.C_STONE, 0.08)
			MK.cyl(st, Vector3(-0.2, 0, 1.6), 0.08, 0.08, 2.4, 6, D.C_WOOD_D, Basis(Vector3.BACK, 0.5))
			MK.rbox(st, Vector3(-1.3, 2.2, 1.6), Vector3(0.7, 0.24, 0.24), D.C_STEEL, 0.05)
		"presse":
			MK.rbox(st, Vector3(0, 1.3, -0.4), Vector3(4.0, 2.6, 3.2), Color("6F7C96"), 0.16)
			MK.rbox(st, Vector3(0, 2.8, -0.4), Vector3(4.3, 0.3, 3.5), D.C_BLUE_METAL, 0.1)
			MK.rbox(st, Vector3(0, 0.9, 1.7), Vector3(2.2, 1.8, 0.8), Color("E0A82E"), 0.1)
			MK.cyl(st, Vector3(1.5, 2.9, -1.2), 0.3, 0.26, 1.6, 8, Color("3A4152"))
			for i in 3:
				MK.rbox(st, Vector3(-1.6 + i * 0.7, 0.3, 2.3), Vector3(0.6, 0.6, 0.6), D.C_STEEL, 0.06)
		"raffinerie":
			MK.cyl(st, Vector3(-1.2, 0, -0.8), 1.3, 1.3, 2.8, 12, D.C_RED)
			MK.cyl(st, Vector3(-1.2, 2.8, -0.8), 1.3, 0.5, 0.5, 12, MK.lighten(D.C_RED, 0.8))
			MK.cyl(st, Vector3(1.4, 0, -1.0), 0.9, 0.9, 2.0, 10, Color("DDE3EE"))
			MK.cyl(st, Vector3(1.4, 2.0, -1.0), 0.9, 0.3, 0.4, 10, D.C_STEEL)
			MK.rbox(st, Vector3(0.2, 1.6, -0.9), Vector3(1.6, 0.2, 0.2), D.C_STEEL, 0.04)
			_barrel(st, Vector3(0.6, 0, 1.6), D.C_RED)
			_barrel(st, Vector3(1.4, 0, 1.9), D.C_RED_D)
			_barrel(st, Vector3(-1.4, 0, 1.8), Color("3A4152"))
		"generator":
			MK.rbox(st, Vector3(0, 0.9, 0), Vector3(2.8, 1.8, 2.4), Color("4B5670"), 0.14)
			MK.rbox(st, Vector3(0, 1.95, 0), Vector3(3.0, 0.25, 2.6), Color("E0A82E"), 0.08)
			MK.cyl(st, Vector3(0.8, 2.0, -0.5), 0.2, 0.2, 1.4, 8, D.C_STEEL)
	MK.inst(st, n)
	if key == "generator":
		MK.glow_box(n, Vector3(0, 1.0, 1.22), Vector3(1.6, 0.5, 0.06), Color("3FD2F5"))
		MK.glow_box(n, Vector3(0.8, 3.5, -0.5), Vector3(0.3, 0.3, 0.3), Color("3FD2F5"))
	elif key == "presse":
		_win(n, Vector3(-1.2, 1.8, 1.22), Vector3(0.5, 0.5, 0.06))
		_win(n, Vector3(1.2, 1.8, 1.22), Vector3(0.5, 0.5, 0.06))
	elif key == "saege":
		_win(n, Vector3(-0.8, 1.3, 1.02), Vector3(0.7, 0.7, 0.06))
	return n


static func _lager(level: int) -> Node3D:
	var n := Node3D.new()
	var st := MK.begin()
	MK.rbox(st, Vector3(0, 1.2, -0.5), Vector3(4.4, 2.4, 3.4), Color("B9A46A"), 0.16)
	MK.rbox(st, Vector3(0, 2.7, 0.35), Vector3(4.8, 0.3, 2.3), D.C_OLIVE, 0.1, Basis(Vector3.RIGHT, 0.5))
	MK.rbox(st, Vector3(0, 2.7, -1.35), Vector3(4.8, 0.3, 2.3), D.C_OLIVE, 0.1, Basis(Vector3.RIGHT, -0.5))
	MK.rbox(st, Vector3(0, 1.0, 1.22), Vector3(1.8, 2.0, 0.2), D.C_WOOD_D, 0.06)
	var cols := [D.C_WOOD, D.C_BLUE_METAL, D.C_OLIVE, D.C_WOOD]
	for i in mini(2 + level, 7):
		_crate(st, Vector3(-1.9 + (i % 4) * 1.25, 0.0 + int(i / 4) * 0.82, 2.2), 0.8, cols[i % 4], 0.1 * i)
	MK.inst(st, n)
	return n


static func _quartier() -> Node3D:
	var n := Node3D.new()
	var st := MK.begin()
	MK.rbox(st, Vector3(0, 1.1, -0.2), Vector3(5.0, 2.2, 2.8), Color("C9B48A"), 0.16)
	MK.rbox(st, Vector3(0, 2.55, 0.5), Vector3(5.4, 0.28, 2.0), D.C_BLUE_METAL, 0.1, Basis(Vector3.RIGHT, 0.45))
	MK.rbox(st, Vector3(0, 2.55, -0.9), Vector3(5.4, 0.28, 2.0), D.C_BLUE_METAL, 0.1, Basis(Vector3.RIGHT, -0.45))
	MK.rbox(st, Vector3(-1.2, 0.95, 1.22), Vector3(1.0, 1.9, 0.16), D.C_WOOD_D, 0.05)
	MK.cyl(st, Vector3(2.0, 2.4, -0.6), 0.25, 0.22, 1.3, 8, Color("8A5A4A"))
	MK.rbox(st, Vector3(2.1, 0.3, 1.9), Vector3(1.4, 0.6, 0.5), D.C_WOOD, 0.06)
	MK.inst(st, n)
	_win(n, Vector3(0.6, 1.3, 1.22), Vector3(0.7, 0.7, 0.06))
	_win(n, Vector3(1.8, 1.3, 1.22), Vector3(0.7, 0.7, 0.06))
	return n


static func _kistenlager() -> Node3D:
	var n := Node3D.new()
	var st := MK.begin()
	MK.rbox(st, Vector3(0, 0.15, 0), Vector3(3.4, 0.3, 3.4), D.C_WOOD_D, 0.08)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			MK.rbox(st, Vector3(1.45 * sx, 1.3, 1.45 * sz), Vector3(0.28, 2.3, 0.28), D.C_WOOD, 0.06)
	MK.rbox(st, Vector3(0, 2.6, 0), Vector3(3.8, 0.28, 3.8), D.C_RED, 0.1)
	MK.inst(st, n)
	var c := chest(D.C_COIN)
	c.position = Vector3(0, 0.3, 0)
	c.scale = Vector3(1.5, 1.5, 1.5)
	n.add_child(c)
	return n


static func _werkstatt() -> Node3D:
	var n := Node3D.new()
	var st := MK.begin()
	MK.rbox(st, Vector3(-0.6, 1.3, -0.6), Vector3(3.8, 2.6, 3.6), Color("8E99B4"), 0.16)
	MK.rbox(st, Vector3(-0.6, 2.8, -0.6), Vector3(4.2, 0.3, 4.0), D.C_RED, 0.1)
	MK.rbox(st, Vector3(-0.6, 1.1, 1.25), Vector3(2.2, 2.0, 0.16), Color("3A4152"), 0.05)
	MK.cyl(st, Vector3(-1.8, 2.9, -1.6), 0.3, 0.25, 1.5, 8, Color("3A4152"))
	MK.rbox(st, Vector3(2.0, 0.5, 1.4), Vector3(1.4, 1.0, 1.0), D.C_WOOD, 0.08)
	MK.rbox(st, Vector3(2.0, 1.15, 1.4), Vector3(0.9, 0.3, 0.5), D.C_STEEL, 0.06)
	MK.cyl(st, Vector3(2.2, 0, -1.4), 0.6, 0.6, 0.3, 10, Color("3A4152"))
	MK.inst(st, n)
	_win(n, Vector3(-2.52, 1.6, -0.4), Vector3(0.06, 0.7, 1.0))
	MK.glow_box(n, Vector3(2.0, 1.4, 1.4), Vector3(0.3, 0.16, 0.3), Color(1.0, 0.5, 0.15))
	return n


static func _garage() -> Node3D:
	var n := Node3D.new()
	var st := MK.begin()
	MK.rbox(st, Vector3(0, 1.4, -0.8), Vector3(7.0, 2.8, 3.8), Color("9AA4B8"), 0.18)
	MK.rbox(st, Vector3(0, 3.0, -0.8), Vector3(7.4, 0.35, 4.2), D.C_BLUE_METAL, 0.12)
	for sx in [-1.0, 1.0]:
		MK.rbox(st, Vector3(1.7 * sx, 1.15, 1.15), Vector3(2.8, 2.2, 0.16), Color("3A4152"), 0.05)
		for i in 4:
			MK.box(st, Vector3(1.7 * sx, 0.4 + i * 0.5, 1.25), Vector3(2.6, 0.06, 0.04), Color("566078"))
	MK.cyl(st, Vector3(3.0, 0, 2.2), 0.5, 0.5, 0.36, 10, Color("23262E"), Basis(Vector3.BACK, PI * 0.5))
	_barrel(st, Vector3(-3.0, 0, 2.0), D.C_RED)
	MK.inst(st, n)
	_win(n, Vector3(0, 2.5, 1.14), Vector3(0.9, 0.3, 0.06))
	return n


static func _funkturm() -> Node3D:
	var n := Node3D.new()
	var st := MK.begin()
	MK.rbox(st, Vector3(0, 0.6, 0), Vector3(2.4, 1.2, 2.4), D.C_STONE, 0.12)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			MK.box(st, Vector3(0.5 * sx, 4.0, 0.5 * sz), Vector3(0.14, 5.8, 0.14), D.C_STEEL, Basis(Vector3(sz, 0, -sx).normalized(), 0.09))
	for i in 4:
		var w := 1.2 - i * 0.2
		MK.box(st, Vector3(0, 2.0 + i * 1.3, 0), Vector3(w, 0.1, w), D.C_RED if i % 2 == 0 else Color.WHITE)
	MK.cyl(st, Vector3(0, 6.8, 0), 0.05, 0.03, 1.6, 5, D.C_STEEL)
	MK.cyl(st, Vector3(0.7, 4.6, 0.2), 0.6, 0.15, 0.25, 10, Color("DDE3EE"), Basis(Vector3.BACK, -1.0))
	MK.inst(st, n)
	MK.glow_box(n, Vector3(0, 8.45, 0), Vector3(0.22, 0.22, 0.22), Color(1, 0.25, 0.2))
	_win(n, Vector3(0, 0.7, 1.22), Vector3(0.7, 0.5, 0.06))
	return n


static func _clanhalle() -> Node3D:
	var n := Node3D.new()
	var st := MK.begin()
	MK.rbox(st, Vector3(0, 0.3, 0), Vector3(7.4, 0.6, 7.0), MK.lighten(D.C_STONE, 0.8), 0.14)
	MK.rbox(st, Vector3(0, 2.0, -0.4), Vector3(6.2, 3.0, 5.0), Color("C9B48A"), 0.2)
	MK.rbox(st, Vector3(0, 3.9, 0.9), Vector3(6.8, 0.36, 3.4), D.C_RED_D, 0.1, Basis(Vector3.RIGHT, 0.55))
	MK.rbox(st, Vector3(0, 3.9, -1.7), Vector3(6.8, 0.36, 3.4), D.C_RED_D, 0.1, Basis(Vector3.RIGHT, -0.55))
	MK.rbox(st, Vector3(0, 1.5, 2.15), Vector3(2.0, 2.4, 0.3), D.C_WOOD_D, 0.08)
	for sx in [-1.0, 1.0]:
		MK.cyl(st, Vector3(1.7 * sx, 0.6, 2.9), 0.3, 0.26, 3.0, 8, D.C_STONE)
	MK.rbox(st, Vector3(0, 3.7, 2.9), Vector3(4.2, 0.4, 0.8), D.C_STONE, 0.1)
	MK.inst(st, n)
	for sx in [-1.0, 1.0]:
		_win(n, Vector3(2.1 * sx, 2.2, 2.12), Vector3(0.7, 1.0, 0.06))
		_flag(n, Vector3(3.2 * sx, 0.6, 3.0), D.C_FLAG if sx > 0 else D.C_RED, 4.0, sx > 0)
	return n


static func _labor() -> Node3D:
	var n := Node3D.new()
	var st := MK.begin()
	MK.rbox(st, Vector3(0, 1.2, 0), Vector3(4.4, 2.4, 4.0), Color("EDEDF2"), 0.18)
	MK.ball(st, Vector3(0, 2.6, 0), Vector3(1.8, 1.4, 1.8), Color("9A5CE0"), 2, 0.0, 5, 10)
	MK.cyl(st, Vector3(1.6, 2.4, 1.2), 0.1, 0.1, 2.0, 6, D.C_STEEL)
	MK.rbox(st, Vector3(0, 1.0, 2.05), Vector3(1.2, 2.0, 0.16), Color("3A4152"), 0.05)
	MK.inst(st, n)
	MK.glow_box(n, Vector3(1.6, 4.5, 1.2), Vector3(0.3, 0.3, 0.3), Color("B46CFF"))
	MK.glow_box(n, Vector3(-1.3, 1.4, 2.02), Vector3(0.7, 0.6, 0.06), Color("B46CFF"))
	return n


static func _schild() -> Node3D:
	var n := Node3D.new()
	var st := MK.begin()
	MK.cyl(st, Vector3.ZERO, 2.4, 2.1, 0.7, 12, D.C_STONE)
	MK.cyl(st, Vector3(0, 0.7, 0), 1.2, 0.8, 1.6, 10, D.C_BLUE_METAL)
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		MK.rbox(st, Vector3(cos(a) * 1.8, 1.2, sin(a) * 1.8), Vector3(0.4, 1.4, 0.4), Color("E0A82E"), 0.08)
	MK.inst(st, n)
	var orb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.8
	sm.height = 1.6
	sm.radial_segments = 12
	sm.rings = 6
	orb.mesh = sm
	orb.material_override = MK.glow(Color("7FE3FF"))
	orb.position = Vector3(0, 3.0, 0)
	n.add_child(orb)
	return n


static func _trap(key: String) -> Node3D:
	var n := Node3D.new()
	var st := MK.begin()
	match key:
		"stachel":
			MK.rbox(st, Vector3(0, 0.08, 0), Vector3(1.7, 0.16, 1.7), D.C_WOOD_D, 0.05)
			for i in 9:
				MK.cone(st, Vector3(-0.5 + (i % 3) * 0.5, 0.16, -0.5 + int(i / 3) * 0.5), 0.14, 0.55, 5, Color("DDE3EE"))
		"kleb":
			MK.cyl(st, Vector3(0, 0, 0), 1.8, 1.8, 0.1, 14, Color("7A5A2A"))
			MK.cyl(st, Vector3(0.3, 0.02, -0.2), 1.2, 1.2, 0.12, 12, Color("B58A3A"))
			_barrel(st, Vector3(-1.2, 0, 1.2), Color("E0A82E"))
		"mine":
			MK.cyl(st, Vector3.ZERO, 0.6, 0.7, 0.3, 10, Color("3A4152"))
			MK.cyl(st, Vector3(0, 0.3, 0), 0.25, 0.25, 0.12, 8, D.C_RED)
	MK.inst(st, n)
	if key == "mine":
		MK.glow_box(n, Vector3(0, 0.5, 0), Vector3(0.14, 0.14, 0.14), Color(1, 0.25, 0.2))
	return n


static func lantern() -> Node3D:
	var n := Node3D.new()
	var st := MK.begin()
	MK.cyl(st, Vector3.ZERO, 0.12, 0.1, 2.2, 6, D.C_WOOD_D)
	MK.rbox(st, Vector3(0, 2.75, 0), Vector3(0.62, 0.14, 0.62), Color("3A4152"), 0.04)
	MK.rbox(st, Vector3(0, 2.2, 0), Vector3(0.56, 0.12, 0.56), Color("3A4152"), 0.04)
	MK.inst(st, n)
	_win(n, Vector3(0, 2.47, 0), Vector3(0.44, 0.44, 0.44))
	return n


static func _flowerbed() -> Node3D:
	var st := MK.begin()
	MK.rbox(st, Vector3(0, 0.12, 0), Vector3(1.7, 0.24, 1.7), D.C_WOOD, 0.06)
	MK.box(st, Vector3(0, 0.22, 0), Vector3(1.45, 0.1, 1.45), Color("6B4A2A"))
	var cols := [Color.WHITE, Color("FFD23E"), Color("F07AB4"), Color("FF7043")]
	for i in 9:
		var p := Vector3(-0.45 + (i % 3) * 0.45, 0.3, -0.45 + int(i / 3) * 0.45)
		MK.box(st, p + Vector3(0, 0.12, 0), Vector3(0.05, 0.3, 0.05), D.C_GRASS_D)
		MK.rbox(st, p + Vector3(0, 0.32, 0), Vector3(0.22, 0.12, 0.22), cols[i % 4], 0.04)
	return _node(st)


static func _statue() -> Node3D:
	var st := MK.begin()
	MK.rbox(st, Vector3(0, 0.5, 0), Vector3(2.4, 1.0, 2.4), D.C_STONE, 0.12)
	MK.rbox(st, Vector3(0, 1.6, 0), Vector3(0.9, 1.2, 0.6), Color("E0A82E"), 0.12)
	MK.rbox(st, Vector3(0, 2.7, 0), Vector3(1.0, 1.0, 0.9), Color("E0A82E"), 0.16)
	MK.rbox(st, Vector3(0.75, 2.0, 0.2), Vector3(0.3, 1.0, 0.3), Color("E0A82E"), 0.08, Basis(Vector3.BACK, -0.6))
	return _node(st)


# ----------------------------------------------------------------- Mauern (für MultiMesh)
## Pfosten-Mesh einer Mauer (steht in jedem Mauerfeld).
static func wall_post(tier: int) -> Mesh:
	if has_glb("wall_post_%d" % tier):
		return glb_mesh("wall_post_%d" % tier)
	var st := MK.begin()
	match tier:
		0:
			MK.rbox(st, Vector3(0, 0.9, 0), Vector3(0.5, 1.8, 0.5), D.C_WOOD, 0.08)
			MK.rbox(st, Vector3(0, 1.85, 0), Vector3(0.62, 0.18, 0.62), D.C_STEEL, 0.05)
		1:
			MK.rbox(st, Vector3(0, 1.05, 0), Vector3(0.9, 2.1, 0.9), D.C_STONE, 0.12)
			MK.rbox(st, Vector3(0, 2.2, 0), Vector3(1.05, 0.24, 1.05), MK.lighten(D.C_STONE, 0.82), 0.06)
		_:
			MK.rbox(st, Vector3(0, 1.25, 0), Vector3(1.0, 2.5, 1.0), Color("5A6A8C"), 0.12)
			MK.rbox(st, Vector3(0, 2.6, 0), Vector3(1.16, 0.26, 1.16), Color("E0A82E"), 0.06)
	return st.commit()


## Gerüst um ein Mauerstück im Bau.
static func wall_site() -> Mesh:
	return glb_mesh("wall_site") if has_glb("wall_site") else wall_post(0)


## Verbindungsstück zwischen zwei benachbarten Mauerfeldern (Länge = 1 Feld, entlang X).
static func wall_link(tier: int) -> Mesh:
	if has_glb("wall_link_%d" % tier):
		return glb_mesh("wall_link_%d" % tier)
	var st := MK.begin()
	var L := D.CELL
	match tier:
		0:
			MK.rbox(st, Vector3(0, 1.25, 0), Vector3(L, 0.3, 0.16), D.C_WOOD, 0.05)
			MK.rbox(st, Vector3(0, 0.6, 0), Vector3(L, 0.3, 0.16), MK.lighten(D.C_WOOD, 0.9), 0.05)
			MK.box(st, Vector3(0, 0.9, 0.02), Vector3(L * 0.92, 0.1, 0.1), D.C_WOOD_D, Basis(Vector3.BACK, 0.42))
		1:
			MK.rbox(st, Vector3(0, 0.9, 0), Vector3(L, 1.8, 0.6), MK.lighten(D.C_STONE, 0.94), 0.08)
		_:
			MK.rbox(st, Vector3(0, 1.1, 0), Vector3(L, 2.2, 0.66), Color("6F7FA6"), 0.08)
			MK.box(st, Vector3(0, 1.6, 0), Vector3(L, 0.14, 0.72), Color("E0A82E"))
	return st.commit()


# ================================================================= Kulissen
static func tree(kind: String, st: SurfaceTool, p: Vector3, rng: RandomNumberGenerator) -> void:
	var s := rng.randf_range(0.85, 1.25)
	match kind:
		"pine", "pine_dense", "snowpine":
			var g := MK.vary(D.C_PINE if kind != "pine" else Color("3F7F45"), 0.1, rng)
			MK.cyl(st, p, 0.22 * s, 0.16 * s, 1.0 * s, 6, D.C_WOOD_D)
			for i in 3:
				var col := g if kind != "snowpine" or i < 2 else Color("F2F7FF")
				MK.cone(st, p + Vector3(0, (0.7 + i * 1.0) * s, 0), (1.5 - i * 0.38) * s, 1.6 * s, 7, MK.lighten(col, 1.0 + i * 0.1))
			if kind == "snowpine":
				MK.cone(st, p + Vector3(0, 3.6 * s, 0), 0.5 * s, 0.7 * s, 7, Color("F2F7FF"))
		"cactus":
			var g2 := MK.vary(Color("5C9A4A"), 0.1, rng)
			MK.cyl(st, p, 0.32 * s, 0.28 * s, 2.2 * s, 7, g2)
			MK.rbox(st, p + Vector3(0.55 * s, 1.1 * s, 0), Vector3(0.6 * s, 0.26 * s, 0.26 * s), g2, 0.06)
			MK.cyl(st, p + Vector3(0.75 * s, 1.1 * s, 0), 0.16 * s, 0.14 * s, 0.9 * s, 6, g2)
		"palm":
			MK.cyl(st, p, 0.24 * s, 0.16 * s, 3.4 * s, 6, Color("B8905A"), Basis(Vector3.BACK, 0.15))
			var top := p + Vector3(-0.5 * s, 3.3 * s, 0)
			for i in 6:
				var a := TAU * i / 6.0
				MK.rbox(st, top + Vector3(cos(a), -0.15, sin(a)) * 0.9 * s, Vector3(1.9 * s, 0.12, 0.6 * s), MK.vary(Color("4FA34A"), 0.1, rng), 0.05,
					Basis(Vector3.UP, -a) * Basis(Vector3.BACK, -0.35))
		"dead":
			var bark := MK.vary(Color("5A4A3E"), 0.1, rng)
			MK.cyl(st, p, 0.24 * s, 0.12 * s, 3.0 * s, 6, bark)
			for i in 3:
				var a2 := rng.randf() * TAU
				MK.cyl(st, p + Vector3(0, (1.4 + i * 0.5) * s, 0), 0.08, 0.04, 1.3 * s, 5, bark, Basis(Vector3.UP, a2) * Basis(Vector3.BACK, 0.9))
		"crystal":
			var c := MK.vary(Color("A6F24A"), 0.12, rng)
			for i in 3:
				var a3 := rng.randf() * TAU
				MK.cyl(st, p + Vector3(cos(a3), 0, sin(a3)) * 0.4 * i, 0.4 * s, 0.05, (2.6 - i * 0.7) * s, 5, c, Basis(Vector3(cos(a3), 0, sin(a3)), 0.25 * i))


static func rock(st: SurfaceTool, p: Vector3, r: float, rng: RandomNumberGenerator, col := D.C_ROCK) -> void:
	MK.ball(st, p + Vector3(0, r * 0.25, 0), Vector3(r, r * rng.randf_range(0.7, 1.1), r), MK.vary(col, 0.1, rng), rng.randi() % 9999, 0.22, 4, 7)


static func bush(st: SurfaceTool, p: Vector3, rng: RandomNumberGenerator, col := D.C_GRASS_D) -> void:
	var r := rng.randf_range(0.5, 0.9)
	MK.ball(st, p + Vector3(0, r * 0.5, 0), Vector3(r, r * 0.8, r), MK.vary(col, 0.12, rng), rng.randi() % 9999, 0.18, 4, 7)


static func flowers(st: SurfaceTool, p: Vector3, rng: RandomNumberGenerator) -> void:
	var cols := [Color.WHITE, Color("FFD23E"), Color("F07AB4"), Color("FFFFFF")]
	for i in 4:
		var q := p + Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5))
		MK.box(st, q + Vector3(0, 0.12, 0), Vector3(0.04, 0.24, 0.04), D.C_GRASS_D)
		MK.box(st, q + Vector3(0, 0.26, 0), Vector3(0.2, 0.06, 0.2), cols[rng.randi() % 4])
		MK.box(st, q + Vector3(0, 0.28, 0), Vector3(0.08, 0.07, 0.08), Color("FFD23E"))


static func fence(st: SurfaceTool, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var n := maxi(1, int(d.length() / 1.6))
	var yaw := atan2(-d.z, d.x)
	for i in n + 1:
		MK.rbox(st, a + d * (float(i) / n) + Vector3(0, 0.55, 0), Vector3(0.22, 1.1, 0.22), D.C_WOOD, 0.05)
	MK.rbox(st, a + d * 0.5 + Vector3(0, 0.8, 0), Vector3(d.length(), 0.16, 0.1), D.C_WOOD_D, 0.04, Basis(Vector3.UP, yaw))
	MK.rbox(st, a + d * 0.5 + Vector3(0, 0.4, 0), Vector3(d.length(), 0.16, 0.1), D.C_WOOD_D, 0.04, Basis(Vector3.UP, yaw))


static func car_wreck(st: SurfaceTool, p: Vector3, yaw: float, col: Color) -> void:
	var b := Basis(Vector3.UP, yaw)
	MK.rbox(st, p + Vector3(0, 0.6, 0), Vector3(3.6, 0.8, 1.7), col, 0.16, b)
	MK.rbox(st, p + Vector3(0, 1.25, 0) + b * Vector3(-0.2, 0, 0), Vector3(1.9, 0.7, 1.5), MK.lighten(col, 0.85), 0.16, b)
	for sx in [-1.1, 1.1]:
		for sz in [-0.8, 0.8]:
			MK.cyl(st, p + b * Vector3(sx, 0.36, sz - 0.1 * signf(sz)), 0.36, 0.36, 0.24, 8, Color("23262E"), b * Basis(Vector3.RIGHT, PI * 0.5 * signf(sz)))


static func bridge(st: SurfaceTool, a: Vector3, b: Vector3, width := 3.0) -> void:
	var d := b - a
	var n := int(d.length() / 0.7)
	var yaw := atan2(-d.z, d.x)
	var bs := Basis(Vector3.UP, yaw)
	for i in n:
		MK.rbox(st, a + d * ((i + 0.5) / n) + Vector3(0, 0.12, 0), Vector3(0.6, 0.16, width), MK.lighten(D.C_WOOD, 0.9 + 0.1 * (i % 2)), 0.04, bs)
	for s in [-1.0, 1.0]:
		MK.rbox(st, a + d * 0.5 + bs * Vector3(0, 0.7, s * width * 0.5), Vector3(d.length(), 0.14, 0.14), D.C_WOOD_D, 0.04, bs)
		for i in 3:
			MK.rbox(st, a + d * (i / 2.0) + bs * Vector3(0, 0.4, s * width * 0.5), Vector3(0.2, 0.9, 0.2), D.C_WOOD_D, 0.04, bs)


## Schatzkiste (Beutekisten, Fundkisten).
static func chest(col: Color) -> Node3D:
	if has_glb("p_chest"):
		return glb("p_chest")
	var n := Node3D.new()
	var st := MK.begin()
	MK.rbox(st, Vector3(0, 0.3, 0), Vector3(1.0, 0.6, 0.7), D.C_WOOD, 0.06)
	MK.rbox(st, Vector3(0, 0.72, 0), Vector3(1.04, 0.3, 0.74), col, 0.12)
	MK.box(st, Vector3(-0.36, 0.45, 0), Vector3(0.1, 0.92, 0.76), Color("E0A82E"))
	MK.box(st, Vector3(0.36, 0.45, 0), Vector3(0.1, 0.92, 0.76), Color("E0A82E"))
	MK.inst(st, n)
	MK.glow_box(n, Vector3(0, 0.55, 0.37), Vector3(0.18, 0.2, 0.06), C_GLOW)
	return n


## Rohstoffhaufen in Expeditionen.
static func pile(res: String) -> Node3D:
	if has_glb("p_pile_" + res):
		return glb("p_pile_" + res)
	var st := MK.begin()
	var rng := RandomNumberGenerator.new()
	rng.seed = res.hash()
	match res:
		"wood":
			for i in 5:
				MK.cyl(st, Vector3(-0.5 + (i % 3) * 0.5, 0.22 + int(i / 3) * 0.42, -0.7), 0.22, 0.22, 1.4, 7, MK.vary(D.C_WOOD, 0.1, rng), Basis(Vector3.RIGHT, PI * 0.5))
		"stone":
			for i in 5:
				MK.rbox(st, Vector3(rng.randf_range(-0.5, 0.5), 0.25 + (i % 2) * 0.35, rng.randf_range(-0.4, 0.4)), Vector3(0.6, 0.45, 0.5), MK.vary(D.C_STONE, 0.1, rng), 0.08,
					Basis(Vector3.UP, rng.randf()))
		"metal":
			for i in 4:
				MK.rbox(st, Vector3(0, 0.1 + i * 0.16, 0), Vector3(1.2, 0.12, 0.8), MK.vary(Color("6F8FC0"), 0.1, rng), 0.03, Basis(Vector3.UP, rng.randf_range(-0.3, 0.3)))
		"fuel":
			for i in 3:
				MK.rbox(st, Vector3(-0.5 + i * 0.5, 0.4, 0), Vector3(0.42, 0.8, 0.6), D.C_RED, 0.08)
				MK.box(st, Vector3(-0.5 + i * 0.5, 0.86, 0.15), Vector3(0.12, 0.12, 0.12), Color("23262E"))
		"cells":
			for i in 3:
				MK.cyl(st, Vector3(-0.4 + i * 0.4, 0, 0), 0.16, 0.16, 0.7, 8, Color("3A4152"))
				MK.cyl(st, Vector3(-0.4 + i * 0.4, 0.2, 0), 0.18, 0.18, 0.3, 8, Color("3FD2F5"))
		"parts":
			MK.cyl(st, Vector3(0, 0.1, 0), 0.5, 0.5, 0.16, 8, Color("C9CED8"))
			MK.cyl(st, Vector3(0.3, 0.3, 0.2), 0.3, 0.3, 0.14, 8, Color("9AA4B8"), Basis(Vector3.BACK, 0.5))
		"shards":
			for i in 3:
				MK.cyl(st, Vector3(-0.3 + i * 0.3, 0, 0), 0.2, 0.02, 0.9 - 0.2 * absf(i - 1.0), 5, Color("FFE98A"))
		_:
			_crate(st, Vector3.ZERO, 0.7, D.C_WOOD)
			MK.cyl(st, Vector3(0.6, 0.05, 0.3), 0.22, 0.22, 0.08, 10, D.C_COIN)
			MK.cyl(st, Vector3(0.5, 0.13, 0.4), 0.22, 0.22, 0.08, 10, D.C_COIN)
	return _node(st, res == "coins" or res == "shards")


## Schleimnest (zerstörbar) und Gegner-Turm mit rotem Banner.
static func nest() -> Node3D:
	if has_glb("p_nest"):
		return glb("p_nest")
	var n := Node3D.new()
	var st := MK.begin()
	MK.ball(st, Vector3(0, 0.9, 0), Vector3(2.0, 1.7, 2.0), Color("6F9A1F"), 5, 0.14, 6, 10)
	MK.ball(st, Vector3(1.2, 0.5, 0.9), Vector3(0.9, 0.8, 0.9), D.C_SLIME, 6, 0.12, 5, 8)
	MK.ball(st, Vector3(-1.1, 0.4, -0.8), Vector3(0.8, 0.7, 0.8), D.C_SLIME, 7, 0.12, 5, 8)
	MK.cyl(st, Vector3(0, 2.0, 0), 0.6, 0.9, 0.5, 10, Color("3F5A14"))
	MK.inst(st, n)
	MK.glow_box(n, Vector3(0, 2.4, 0), Vector3(0.7, 0.2, 0.7), Color("C8F04A"))
	return n


static func enemy_tower() -> Node3D:
	if has_glb("p_enemy_tower"):
		return glb("p_enemy_tower")
	var n := Node3D.new()
	var st := MK.begin()
	var dk := Color("6B4A32")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			MK.rbox(st, Vector3(0.9 * sx, 2.2, 0.9 * sz), Vector3(0.3, 4.4, 0.3), dk, 0.06)
	MK.rbox(st, Vector3(0, 4.4, 0), Vector3(2.6, 0.3, 2.6), dk, 0.08)
	MK.box(st, Vector3(0.95, 2.2, 0), Vector3(0.12, 3.0, 0.12), dk, Basis(Vector3.RIGHT, 0.6))
	MK.box(st, Vector3(-0.95, 2.2, 0), Vector3(0.12, 3.0, 0.12), dk, Basis(Vector3.RIGHT, -0.6))
	MK.rbox(st, Vector3(0, 3.0, 1.0), Vector3(1.3, 1.9, 0.08), D.C_RED_D, 0.04)
	MK.ball(st, Vector3(0, 3.2, 1.07), Vector3(0.35, 0.35, 0.06), Color("F2E6E6"), 1, 0.0, 4, 8)
	MK.ball(st, Vector3(0, 5.1, 0), Vector3(0.6, 0.55, 0.6), D.C_SLIME, 2, 0.0, 5, 9)
	MK.inst(st, n)
	return n


static func cage() -> Node3D:
	if has_glb("p_cage"):
		return glb("p_cage")
	var st := MK.begin()
	MK.rbox(st, Vector3(0, 0.1, 0), Vector3(2.4, 0.2, 2.4), D.C_WOOD_D, 0.05)
	MK.rbox(st, Vector3(0, 2.5, 0), Vector3(2.4, 0.2, 2.4), D.C_WOOD_D, 0.05)
	for i in 12:
		var a := TAU * i / 12.0
		MK.cyl(st, Vector3(cos(a) * 1.05, 0.2, sin(a) * 1.05), 0.07, 0.07, 2.3, 5, D.C_STEEL)
	return _node(st)


static func race_gate(col: Color) -> Node3D:
	if has_glb("p_gate"):
		return glb("p_gate")
	var n := Node3D.new()
	var st := MK.begin()
	for s in [-1.0, 1.0]:
		MK.rbox(st, Vector3(3.0 * s, 1.8, 0), Vector3(0.4, 3.6, 0.4), col, 0.08)
	MK.rbox(st, Vector3(0, 3.7, 0), Vector3(6.6, 0.5, 0.4), Color.WHITE, 0.08)
	for i in 6:
		MK.box(st, Vector3(-2.75 + i * 1.1, 3.7, 0.02), Vector3(0.55, 0.5, 0.42), Color("23262E"))
	MK.inst(st, n)
	return n


# ================================================================= Fahrzeuge
static func vehicle(key: String) -> Node3D:
	if has_glb("v_" + key):
		return glb("v_" + key)
	var n := Node3D.new()
	var st := MK.begin()
	var tire := Color("23262E")
	var wheels: Array = []
	match key:
		"quad":
			MK.rbox(st, Vector3(0, 0.75, 0), Vector3(1.0, 0.5, 1.9), D.C_RED, 0.14)
			MK.rbox(st, Vector3(0, 1.05, -0.3), Vector3(0.7, 0.3, 0.8), Color("23262E"), 0.1)
			MK.rbox(st, Vector3(0, 1.2, 0.6), Vector3(1.1, 0.1, 0.1), D.C_STEEL, 0.03)
			wheels = [Vector3(-0.75, 0.45, 0.7), Vector3(0.75, 0.45, 0.7), Vector3(-0.75, 0.45, -0.7), Vector3(0.75, 0.45, -0.7)]
		"bike":
			MK.rbox(st, Vector3(-0.3, 0.8, 0), Vector3(0.5, 0.5, 2.0), Color("3A4152"), 0.12)
			MK.rbox(st, Vector3(-0.3, 1.1, -0.2), Vector3(0.45, 0.25, 0.8), D.C_WOOD_D, 0.08)
			MK.rbox(st, Vector3(0.7, 0.65, -0.1), Vector3(0.9, 0.6, 1.5), D.C_OLIVE, 0.2)
			MK.rbox(st, Vector3(-0.3, 1.3, 0.7), Vector3(0.9, 0.08, 0.08), D.C_STEEL, 0.03)
			wheels = [Vector3(-0.3, 0.45, 0.95), Vector3(-0.3, 0.45, -0.95), Vector3(1.2, 0.4, -0.2)]
		"buggy":
			MK.rbox(st, Vector3(0, 0.8, 0), Vector3(1.7, 0.5, 2.8), Color("E0A82E"), 0.16)
			for sx in [-1.0, 1.0]:
				MK.box(st, Vector3(0.75 * sx, 1.5, -0.2), Vector3(0.1, 1.0, 0.1), D.C_STEEL)
				MK.box(st, Vector3(0.75 * sx, 1.5, 0.7), Vector3(0.1, 1.0, 0.1), D.C_STEEL, Basis(Vector3.RIGHT, 0.4))
			MK.rbox(st, Vector3(0, 2.0, -0.2), Vector3(1.7, 0.1, 1.4), D.C_STEEL, 0.03)
			MK.rbox(st, Vector3(0, 1.0, 1.5), Vector3(1.9, 0.3, 0.3), D.C_STEEL, 0.06)
			wheels = [Vector3(-1.0, 0.55, 1.0), Vector3(1.0, 0.55, 1.0), Vector3(-1.0, 0.55, -1.0), Vector3(1.0, 0.55, -1.0)]
		"pickup":
			MK.rbox(st, Vector3(0, 0.9, 0), Vector3(2.0, 0.7, 3.8), D.C_BLUE_METAL, 0.18)
			MK.rbox(st, Vector3(0, 1.6, 0.7), Vector3(1.8, 0.8, 1.4), MK.lighten(D.C_BLUE_METAL, 0.85), 0.18)
			MK.rbox(st, Vector3(0, 1.45, -1.0), Vector3(1.9, 0.4, 1.7), MK.lighten(D.C_BLUE_METAL, 0.7), 0.08)
			MK.cyl(st, Vector3(0, 1.6, -1.0), 0.25, 0.2, 0.6, 8, D.C_STEEL)
			MK.rbox(st, Vector3(0, 2.3, -0.7), Vector3(0.3, 0.3, 1.3), Color("3A4152"), 0.06)
			wheels = [Vector3(-1.1, 0.55, 1.3), Vector3(1.1, 0.55, 1.3), Vector3(-1.1, 0.55, -1.3), Vector3(1.1, 0.55, -1.3)]
		"hover":
			MK.rbox(st, Vector3(0, 0.45, 0), Vector3(2.4, 0.6, 3.6), Color("23262E"), 0.28)
			MK.rbox(st, Vector3(0, 0.95, 0.2), Vector3(1.9, 0.5, 2.6), Color("F07A2E"), 0.16)
			MK.cyl(st, Vector3(0, 1.2, -1.5), 0.8, 0.8, 0.4, 12, D.C_STEEL, Basis(Vector3.RIGHT, PI * 0.5))
			MK.rbox(st, Vector3(0, 1.5, 0.9), Vector3(1.5, 0.5, 0.1), Color("7FD0F5"), 0.04, Basis(Vector3.RIGHT, -0.4))
	for w in wheels:
		var r: float = w.y
		MK.cyl(st, w + Vector3(-0.16 if w.x <= 0 else 0.16, 0, 0), r, r, 0.34, 10, tire, Basis(Vector3.BACK, PI * 0.5 * (1.0 if w.x <= 0 else -1.0)))
	MK.inst(st, n)
	MK.glow_box(n, Vector3(0, 0.85, (1.0 if key == "quad" else 1.45) if key != "pickup" else 1.92), Vector3(0.6, 0.14, 0.06), C_GLOW)
	return n


# ================================================================= Waffen der Helden
## Waffenmodell mit Lauf entlang +Z, Griff im Ursprung.
static func weapon(key: String) -> Node3D:
	if has_glb("w_" + key):
		return glb("w_" + key)
	var st := MK.begin()
	var dk := Color("2E3340")
	var steel := Color("8A94A8")
	var hero_col: Color = D.HEROES[D.WEAPONS[key].hero].color
	match key:
		"j_rifle", "j_burst":
			MK.rbox(st, Vector3(0, 0.08, 0.3), Vector3(0.14, 0.2, 0.9), dk, 0.04)
			MK.cyl(st, Vector3(0, 0.1, 0.7), 0.05, 0.05, 0.4, 6, steel, Basis(Vector3.RIGHT, PI * 0.5))
			MK.rbox(st, Vector3(0, -0.12, 0.25), Vector3(0.1, 0.3, 0.14), hero_col, 0.03)
			MK.rbox(st, Vector3(0, 0.02, -0.25), Vector3(0.12, 0.2, 0.36), D.C_WOOD, 0.04)
			if key == "j_burst":
				MK.rbox(st, Vector3(0, 0.24, 0.3), Vector3(0.08, 0.1, 0.3), Color("E0A82E"), 0.03)
		"j_parcel":
			MK.cyl(st, Vector3(0, 0.1, -0.1), 0.17, 0.17, 0.9, 8, hero_col, Basis(Vector3.RIGHT, PI * 0.5))
			MK.rbox(st, Vector3(0, 0.1, 0.85), Vector3(0.36, 0.3, 0.3), Color("C9A66A"), 0.05)
			MK.rbox(st, Vector3(0, -0.1, 0.1), Vector3(0.1, 0.24, 0.12), dk, 0.03)
		"m_flame", "m_water":
			MK.cyl(st, Vector3(0, 0.06, -0.1), 0.1, 0.08, 0.9, 7, dk, Basis(Vector3.RIGHT, PI * 0.5))
			MK.cyl(st, Vector3(0, 0.06, 0.78), 0.12, 0.15, 0.16, 7, steel if key == "m_flame" else Color("5DB2EA"), Basis(Vector3.RIGHT, PI * 0.5))
			MK.rbox(st, Vector3(0, -0.1, 0.1), Vector3(0.1, 0.24, 0.12), hero_col, 0.03)
			MK.cyl(st, Vector3(0, -0.02, 0.3), 0.09, 0.09, 0.3, 7, D.C_RED if key == "m_flame" else Color("5DB2EA"), Basis(Vector3.RIGHT, PI * 0.5))
		"m_fireball", "g_cracker", "b_cement", "a_cloud", "g_cake":
			var c := {"m_fireball": D.C_FIRE, "g_cracker": Color("F07AB4"), "b_cement": D.C_STONE, "a_cloud": Color("9A5CE0"), "g_cake": Color("F2D6B0")}
			MK.cyl(st, Vector3(0, 0.1, -0.15), 0.14, 0.14, 0.85, 8, dk, Basis(Vector3.RIGHT, PI * 0.5))
			MK.cyl(st, Vector3(0, 0.1, 0.62), 0.19, 0.19, 0.18, 8, c[key], Basis(Vector3.RIGHT, PI * 0.5))
			MK.rbox(st, Vector3(0, -0.02, 0.2), Vector3(0.3, 0.24, 0.3), c[key], 0.06)
			MK.rbox(st, Vector3(0, -0.1, -0.1), Vector3(0.1, 0.26, 0.12), D.C_WOOD, 0.03)
		"b_nailer":
			MK.rbox(st, Vector3(0, 0.08, 0.3), Vector3(0.22, 0.24, 0.9), Color("E0A82E"), 0.05)
			MK.cyl(st, Vector3(0, 0.1, 0.7), 0.1, 0.12, 0.25, 7, dk, Basis(Vector3.RIGHT, PI * 0.5))
			MK.rbox(st, Vector3(0, -0.14, 0.05), Vector3(0.12, 0.3, 0.14), dk, 0.03)
		"b_ball":
			MK.cyl(st, Vector3(0, 0, 0), 0.05, 0.05, 0.6, 5, steel, Basis(Vector3.RIGHT, PI * 0.5))
			MK.ball(st, Vector3(0, 0, 0.9), Vector3(0.36, 0.36, 0.36), Color("3A4152"), 3, 0.0, 5, 8)
		"a_spark", "a_shrink":
			MK.cyl(st, Vector3(0, 0.06, -0.15), 0.06, 0.06, 0.9, 6, steel, Basis(Vector3.RIGHT, PI * 0.5))
			MK.ball(st, Vector3(0, 0.06, 0.82), Vector3(0.16, 0.16, 0.16), Color("7FE3FF") if key == "a_spark" else Color("C8F04A"), 2, 0.0, 4, 8)
			MK.rbox(st, Vector3(0, 0.02, 0.2), Vector3(0.18, 0.2, 0.3), hero_col, 0.05)
		"y_rifle":
			MK.rbox(st, Vector3(0, 0.06, 0.2), Vector3(0.1, 0.14, 0.9), D.C_WOOD, 0.04)
			MK.cyl(st, Vector3(0, 0.08, 0.6), 0.035, 0.035, 0.8, 6, dk, Basis(Vector3.RIGHT, PI * 0.5))
			MK.cyl(st, Vector3(0, 0.2, 0.05), 0.05, 0.05, 0.4, 6, dk, Basis(Vector3.RIGHT, PI * 0.5))
		"y_bow", "y_swarm":
			var bc := D.C_WOOD if key == "y_bow" else Color("3FA35A")
			MK.rbox(st, Vector3(0, 0.45, 0.3), Vector3(0.07, 0.6, 0.08), bc, 0.03, Basis(Vector3.RIGHT, -0.35))
			MK.rbox(st, Vector3(0, -0.45, 0.3), Vector3(0.07, 0.6, 0.08), bc, 0.03, Basis(Vector3.RIGHT, 0.35))
			MK.box(st, Vector3(0, 0, 0.12), Vector3(0.02, 1.5, 0.02), Color("F2F2F2"))
			MK.box(st, Vector3(0, 0, 0.5), Vector3(0.03, 0.03, 0.9), Color("F2F2F2"))
		"g_sparkler":
			MK.cyl(st, Vector3(0, 0.05, -0.2), 0.04, 0.04, 1.0, 5, D.C_WOOD, Basis(Vector3.RIGHT, PI * 0.5))
			MK.cyl(st, Vector3(0, 0.05, 0.6), 0.09, 0.09, 0.35, 6, Color("F07AB4"), Basis(Vector3.RIGHT, PI * 0.5))
		_:
			MK.rbox(st, Vector3(0, 0.06, 0.2), Vector3(0.12, 0.16, 0.6), dk, 0.04)
	return _node(st, true)
