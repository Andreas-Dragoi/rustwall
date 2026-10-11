extends Node3D
## Bauplatz der Außenbasis: leuchtende Bodenplatte (o_pad), blasser Umriss des Gebäudes, Preisschild
## (Symbol + Restmenge je Rohstoff, Fehlendes rot) und ein Kreis, der sich beim Bezahlen füllt.
## Bezahlt wird in expedition.gd: Steht der Held auf der Platte, fließt alle 0,08 s eine Einheit aus dem Rucksack herüber.

const D = preload("res://src/data.gd")
const Models = preload("res://src/models.gd")
const MK = preload("res://src/mk.gd")
const UI = preload("res://src/ui.gd")

const C_OK := Color(0.35, 0.8, 1.0)
const C_LOCK := Color(0.55, 0.6, 0.7)

var def: Dictionary
var key := ""
var kind := ""
var price := {}                  # voller Preis
var paid := {}                   # Verweis in den Spielstand (P.outpost_paid)
var center := Vector2.ZERO
var line_a := Vector2.ZERO
var line_b := Vector2.ZERO
var is_line := false
var locked := false
var done := false
var rebuild := false             # Zentrale nach Zerstörung: halber Preis
var _sign: Node3D
var _labels := {}
var _ghost: Node3D
var _arc: MeshInstance3D
var _arc_mesh: ImmediateMesh
var _plates: Array = []
var _k_shown := -1.0
var _lock_l: Label3D
var _icons: Array = []


## pos: Mitte (bei Mauern Mitte der Linie), a/b: Linienenden in Weltkoordinaten (nur Mauern), yaw: Ausrichtung des Umrisses.
func setup(pad_def: Dictionary, full_price: Dictionary, paid_ref: Dictionary, pos: Vector2, yaw: float, ghost_model: String, a := Vector2.ZERO, b := Vector2.ZERO) -> void:
	def = pad_def
	key = String(def.key)
	kind = String(def.kind)
	price = full_price
	paid = paid_ref
	center = pos
	is_line = def.has("line")
	line_a = a
	line_b = b
	position = Vector3(pos.x, 0, pos.y)
	# Bodenplatten
	if is_line:
		var n := maxi(2, int(a.distance_to(b) / 3.4) + 1)
		for i in n:
			var q: Vector2 = a.lerp(b, float(i) / float(n - 1))
			var pl := Models.glb("o_pad")
			pl.position = Vector3(q.x - pos.x, 0.02, q.y - pos.y)
			pl.scale = Vector3(0.75, 1, 0.75)
			add_child(pl)
			_plates.append(pl)
	else:
		var pl2 := Models.glb("o_pad")
		pl2.position.y = 0.02
		add_child(pl2)
		_plates.append(pl2)
	# blasser Umriss
	if ghost_model != "" and Models.has_glb(ghost_model):
		if is_line:
			_ghost = Node3D.new()
			add_child(_ghost)
			var d := b - a
			var n2 := int(round(d.length() / D.CELL)) + 1
			for i in n2:
				var q2: Vector2 = a.lerp(b, float(i) / float(maxi(n2 - 1, 1)))
				var g := Models.glb(ghost_model)
				g.position = Vector3(q2.x - pos.x, 0, q2.y - pos.y)
				_ghost.add_child(g)
		else:
			_ghost = Models.glb(ghost_model, 1)
			_ghost.rotation.y = yaw
			add_child(_ghost)
		var gm := MK.glow(Color(0.45, 0.8, 1.0, 0.22), true)
		for mi in _ghost.find_children("*", "GeometryInstance3D", true, false):
			(mi as GeometryInstance3D).material_override = gm
			(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Fortschrittskreis
	_arc_mesh = ImmediateMesh.new()
	_arc = MeshInstance3D.new()
	_arc.mesh = _arc_mesh
	_arc.material_override = MK.glow(Color("FFD23E"))
	_arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not is_line:
		add_child(_arc)
	# Preisschild
	_sign = Node3D.new()
	_sign.position = Vector3(0, 3.4 if kind != "wall" else 2.6, 0)
	add_child(_sign)
	var title := _label3d(String(def.name), 64, Color.WHITE)
	title.position = Vector3(0, 0.75, 0)
	_sign.add_child(title)
	_lock_l = _label3d("", 52, Color("FFB0B0"))
	_lock_l.position = Vector3(0, -0.6, 0)
	_sign.add_child(_lock_l)
	var keys: Array = []
	for r in D.RES:
		if price.has(r):
			keys.append(r)
	for i in keys.size():
		var r: String = keys[i]
		var x := (i - (keys.size() - 1) * 0.5) * 2.3
		var sp := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(1.0, 1.0)
		sp.mesh = qm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.no_depth_test = true
		mat.render_priority = 4
		mat.albedo_texture = load("res://icons/res_%s.png" % r)
		sp.material_override = mat
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sp.position = Vector3(x - 0.62, 0, 0)
		_sign.add_child(sp)
		_icons.append(mat)
		var l := _label3d("", 60, D.C_GOLD)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.position = Vector3(x - 0.15, 0, 0)
		_sign.add_child(l)
		_labels[r] = l
	refresh({})


func _label3d(t: String, fs: int, col: Color) -> Label3D:
	var l := Label3D.new()
	l.text = t
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font = UI.font(true)
	l.font_size = fs
	l.outline_size = 18
	l.pixel_size = 0.01
	l.modulate = col
	l.outline_modulate = Color("081526")
	l.no_depth_test = true
	l.render_priority = 5
	return l


## Steht der Held auf dem Platz?
func on_pad(pp: Vector2) -> bool:
	if is_line:
		return Geometry2D.get_closest_point_to_segment(pp, line_a, line_b).distance_to(pp) < D.EXP_PAD_RADIUS
	return pp.distance_to(center) < D.EXP_PAD_RADIUS


## Abstand für den Bot (nächster Punkt des Platzes).
func stand_point(pp: Vector2) -> Vector2:
	if is_line:
		return Geometry2D.get_closest_point_to_segment(pp, line_a, line_b)
	return center


func due() -> Dictionary:
	var out := {}
	for r in price:
		var k := 0.5 if rebuild else 1.0
		var rest := float(price[r]) * k - float(paid.get(r, 0.0))
		if rest > 0.001:
			out[r] = rest
	return out


func progress() -> float:
	var tot := 0.0
	var got := 0.0
	var k := 0.5 if rebuild else 1.0
	for r in price:
		tot += float(price[r]) * k
		got += minf(float(paid.get(r, 0.0)), float(price[r]) * k)
	return got / tot if tot > 0.0 else 1.0


## Aktualisiert Schild und Kreis. pack: Rucksackinhalt (Fehlendes wird rot).
func refresh(pack: Dictionary) -> void:
	var rest := due()
	for r in _labels:
		var l: Label3D = _labels[r]
		var v := float(rest.get(r, 0.0))
		l.text = "✓" if v <= 0.0 else str(int(ceil(v)))
		l.modulate = UI.GREEN if v <= 0.0 else (D.C_GOLD if float(pack.get(r, 0.0)) >= 1.0 else Color("FF5A5A"))
	var k := progress()
	if absf(k - _k_shown) > 0.004:
		_k_shown = k
		_draw_arc(k)


func set_locked(v: bool, why := "") -> void:
	locked = v
	_lock_l.text = why if v else ""
	for c in _sign.get_children():
		if c is Label3D:
			c.modulate.a = 0.55 if v else 1.0
	for m in _icons:
		m.albedo_color.a = 0.55 if v else 1.0
	_lock_l.modulate.a = 1.0


func _draw_arc(k: float) -> void:
	_arc_mesh.clear_surfaces()
	if k <= 0.0 or is_line:
		return
	var r0 := D.EXP_PAD_RADIUS + 0.12
	var r1 := D.EXP_PAD_RADIUS + 0.38
	var n := maxi(2, int(48 * k))
	_arc_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in n + 1:
		var a := -PI * 0.5 + TAU * k * float(i) / float(n)
		var c := Vector3(cos(a), 0, sin(a))
		_arc_mesh.surface_add_vertex(c * r1 + Vector3(0, 0.09, 0))
		_arc_mesh.surface_add_vertex(c * r0 + Vector3(0, 0.09, 0))
	_arc_mesh.surface_end()


## Bezahlt: Platte, Umriss und Schild verschwinden.
func finish() -> void:
	done = true
	visible = false
