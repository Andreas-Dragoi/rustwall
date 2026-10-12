extends Node3D
## Kennzeichen der Elite-Gegner und Minibosse (Paket G2, 6.2): goldene Krone über dem Kopf (models/fx_elite_crown.glb),
## leuchtende Aura am Boden (models/fx_elite_aura.glb) – beide als MultiMesh – und ein Namensschild (Label3D).
## Die Horde meldet neue Elite-Gegner mit add() und ruft update() einmal je Bild.

const D = preload("res://src/data.gd")
const Models = preload("res://src/models.gd")
const MK = preload("res://src/mk.gd")
const UI = preload("res://src/ui.gd")
const MAX := 24

var tagged: Array = []              # E (Elite oder Miniboss)
var _crown: MultiMesh
var _aura: MultiMesh
var _labels: Array = []
var _t := 0.0


func _ready() -> void:
	_crown = _mm("fx_elite_crown", false)
	_aura = _mm("fx_elite_aura", true)


func _mm(name: String, glow: bool) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var mesh: Mesh = null
	if Models.has_glb(name):
		mesh = _first_mesh(Models.glb(name))
	if mesh == null:
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0 if not glow else 1.0
		cm.bottom_radius = 0.4 if not glow else 1.0
		cm.height = 0.3 if not glow else 0.03
		mesh = cm
	mm.mesh = mesh
	mm.instance_count = MAX
	mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-160, -6, -160), Vector3(320, 40, 320))
	if glow:
		mi.material_override = MK.glow(Color(1.0, 0.82, 0.25, 0.55), true)
	else:
		mi.material_override = MK.mat_lin() if Models.has_glb(name) else MK.glow(Color(1.0, 0.8, 0.2), false)
	add_child(mi)
	return mm


func _first_mesh(n: Node) -> Mesh:
	var out: Mesh = null
	if n is MeshInstance3D:
		out = (n as MeshInstance3D).mesh
	else:
		for c in n.get_children():
			out = _first_mesh(c)
			if out != null:
				break
	if n.get_parent() == null:
		n.free()
	return out


func add(e) -> void:
	if tagged.has(e):
		return
	if tagged.size() >= MAX:
		return
	tagged.append(e)


func clear() -> void:
	tagged.clear()
	for l in _labels:
		l.visible = false
	if _crown != null:
		_crown.visible_instance_count = 0
		_aura.visible_instance_count = 0


func _label(i: int) -> Label3D:
	while _labels.size() <= i:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.render_priority = 6
		l.outline_render_priority = 5
		l.font = UI.font(true)
		l.font_size = 44
		l.outline_size = 14
		l.pixel_size = 0.0085
		l.outline_modulate = Color("06142E")
		add_child(l)
		_labels.append(l)
	return _labels[i]


func _height(h, e) -> float:
	var vis = h._vis[e.t]
	if vis != null and vis.vat != null:
		return float(vis.vat.info.get("height", 1.5)) * e.vs * (0.6 if e.shrink > 0.0 else 1.0)
	return 1.2 * e.sc


func update(h, dt: float) -> void:
	_t += dt
	var n := 0
	var i := tagged.size() - 1
	while i >= 0:
		var e = tagged[i]
		if e.st == 2 or e.hide:
			tagged.remove_at(i)
		i -= 1
	for e in tagged:
		var top: float = _height(h, e) + e.alt
		var p := Vector3(e.p.x, 0, e.p.y)
		var mini: bool = String(D.ENEMIES[e.t].role) == "miniboss"
		var ks: float = 1.0 + (0.5 if mini else 0.0)
		var bob := sin(_t * 3.0 + e.ph) * 0.08
		var visible: bool = not e.under
		var cs := 0.0 if not visible else ks
		_crown.set_instance_transform(n, Transform3D(Basis(Vector3.UP, _t * 1.4 + e.ph).scaled(Vector3.ONE * maxf(cs, 0.001)), p + Vector3(0, top + 0.12 + bob, 0)))
		_crown.set_instance_color(n, Color(1.0, 0.45, 0.4) if mini else Color.WHITE)
		var ar: float = (e.r * 1.6 + 0.4) * (1.0 + sin(_t * 4.0 + e.ph) * 0.06) * (1.0 if visible else 0.001)
		_aura.set_instance_transform(n, Transform3D(Basis(Vector3.UP, -_t * 0.8).scaled(Vector3(ar, 1.0, ar)), p + Vector3(0, 0.06 + e.alt * 0.0, 0)))
		_aura.set_instance_color(n, Color(1.0, 0.35, 0.3, 0.6) if mini else Color(1.0, 0.85, 0.3, 0.6))
		var l := _label(n)
		l.visible = visible
		l.text = String(D.ENEMIES[e.t].name) if mini else "Elite · " + String(D.ENEMIES[e.t].name)
		l.modulate = Color(1.0, 0.55, 0.45) if mini else Color("FFD23E")
		l.position = p + Vector3(0, top + 0.9 * ks, 0)
		n += 1
	for k in range(n, _labels.size()):
		_labels[k].visible = false
	_crown.visible_instance_count = n
	_aura.visible_instance_count = n
