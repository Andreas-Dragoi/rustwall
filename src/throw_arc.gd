extends Node3D
## Paket H: Wurfbahn beim Zielen mit Bogenwurf-Waffen (Granaten, Flaschen, Minen): leuchtende Punkte auf der
## Flugbahn von der Mündung bis zum Ziel, dazu ein Ring am Einschlag. Ein MultiMesh, ein Zeichenaufruf.

const DH = preload("res://src/data_helden.gd")
const MK = preload("res://src/mk.gd")

var _mm: MultiMesh
var _mi: MultiMeshInstance3D
var _ring: MeshInstance3D
var _t := 0.0
var shown := false


func _ready() -> void:
	top_level = true
	var dot := SphereMesh.new()
	dot.radius = 0.07
	dot.height = 0.14
	dot.radial_segments = 6
	dot.rings = 3
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = dot
	_mm.instance_count = DH.ARC_DOTS
	_mm.visible_instance_count = 0
	_mi = MultiMeshInstance3D.new()
	_mi.multimesh = _mm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mi.material_override = mat
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mi)
	_ring = MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.42
	tor.outer_radius = 0.55
	tor.rings = 16
	tor.ring_segments = 4
	_ring.mesh = tor
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(1, 1, 1, 0.55)
	_ring.material_override = rm
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	hide_arc()


func hide_arc() -> void:
	if not shown and _mm != null and _mm.visible_instance_count == 0:
		return
	shown = false
	if _mm != null:
		_mm.visible_instance_count = 0
	if _ring != null:
		_ring.visible = false


## Zeigt die Bahn von a nach b (Welt) als Bogen; col = Farbe der Waffe.
func show_arc(a: Vector3, b: Vector3, col: Color) -> void:
	if _mm == null:
		return
	shown = true
	_t += get_process_delta_time()
	global_transform = Transform3D.IDENTITY
	var dist := Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
	var h := clampf(dist * 0.28, 0.8, 4.0)
	var n := DH.ARC_DOTS
	var phase := fposmod(_t * 1.6, 1.0)          # Punkte wandern langsam zum Ziel
	for i in n:
		var t := (float(i) + phase) / float(n)
		var p := a.lerp(b, t)
		p.y = lerpf(a.y, b.y, t) + 4.0 * h * t * (1.0 - t)
		var s := 0.6 + 0.6 * t
		_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * s), p))
		_mm.set_instance_color(i, Color(col.r, col.g, col.b, 0.35 + 0.5 * t))
	_mm.visible_instance_count = n
	_ring.visible = true
	_ring.global_position = Vector3(b.x, 0.08, b.z)
	var k := 1.0 + 0.08 * sin(_t * 8.0)
	_ring.scale = Vector3(k, 1.0, k)
	(_ring.material_override as StandardMaterial3D).albedo_color = Color(col.r, col.g, col.b, 0.6)
