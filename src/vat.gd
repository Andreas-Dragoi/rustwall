extends RefCounted
## Lädt Gegner-Modelle mit Animations-Textur (models/e_<key>.glb + e_<key>_vat.png + e_<key>.json, erzeugt von
## blender/vat_bake.py) und baut daraus Mesh, Texturen und Material für shaders/vat.gdshader.
## Eine später hinzukommende Datei wird ohne Code-Änderung gefunden: has(key) prüft nur, ob die drei Dateien da sind.

const Models = preload("res://src/models.gd")

static var _cache := {}
static var _shader: Shader


static func path(key: String, ext: String) -> String:
	return "res://models/e_%s%s" % [key, ext]


## Gibt es für diese Art ein eigenes Modell mit Animations-Textur?
static func has(key: String) -> bool:
	if _cache.has(key):
		return _cache[key] != null
	if not (ResourceLoader.exists(path(key, ".glb")) and ResourceLoader.exists(path(key, "_vat.png")) and ResourceLoader.exists(path(key, ".json"))):
		_cache[key] = null
		return false
	return true


## Beschreibung eines Boss-Modells (echte Figur mit AnimationPlayer) oder {}.
static func boss_info(key: String) -> Dictionary:
	if not (ResourceLoader.exists(path(key, ".glb")) and ResourceLoader.exists(path(key, ".json"))):
		return {}
	var js = load(path(key, ".json"))
	if js == null or not (js.data is Dictionary) or String(js.data.get("kind", "")) != "boss":
		return {}
	return js.data


## {mesh, hi, lo, n, info, clips: {name: nummer}, list: [namen], dur: [s], loop: [bool], stride, height}
static func data(key: String) -> Dictionary:
	if _cache.has(key) and _cache[key] != null:
		return _cache[key]
	var js = load(path(key, ".json"))
	if js == null or not (js.data is Dictionary) or String(js.data.get("kind", "vat")) != "vat":
		_cache[key] = null
		return {}
	var info: Dictionary = js.data
	var tex: Texture2D = load(path(key, "_vat.png"))
	var img: Image = tex.get_image()
	if img.is_compressed():
		push_error("Animations-Textur %s ist komprimiert importiert – Import auf „Lossless“ stellen" % key)
		img.decompress()
	if img.get_format() != Image.FORMAT_RGB8:
		img.convert(Image.FORMAT_RGB8)
	var w := int(info.width)
	var r := int(info.rows)
	var out := {"info": info, "key": key}
	var names := ["hi", "lo", "n"]
	for i in 3:
		out[names[i]] = ImageTexture.create_from_image(img.get_region(Rect2i(0, i * r, w, r)))
	out["mesh"] = _mesh(key)
	var clips := {}
	var list: Array = []
	var arr: Array = []
	var dur: Array = []
	var loop: Array = []
	var hit: Array = []
	var rpf := int(info.rpf)
	for cn in info.clips:
		var c: Dictionary = info.clips[cn]
		clips[cn] = list.size()
		list.append(cn)
		arr.append(Vector4(float(c.row), float(c.n), 1.0 if c.loop else 0.0, 0.0))
		dur.append(float(c.dur))
		loop.append(bool(c.loop))
		hit.append(float(c.get("hit", -1.0)))
	while arr.size() < 16:
		arr.append(Vector4(0, 1, 0, 0))
	out["clips"] = clips
	out["list"] = list
	out["clip_arr"] = arr
	out["dur"] = dur
	out["loop"] = loop
	out["hit"] = hit
	out["stride"] = float(info.clips.walk.stride) if info.clips.has("walk") and float(info.clips.walk.stride) > 0.0 else 1.0
	out["height"] = float(info.height)
	out["rpf"] = rpf
	_cache[key] = out
	return out


## Das Mesh "body" ohne LOD und ohne Schatten-Mesh (beides würde die Zuordnung zur Textur verlieren).
static func _mesh(key: String) -> ArrayMesh:
	var scene: PackedScene = load(path(key, ".glb"))
	var src: Node = scene.instantiate()
	var mi := Models._find_mesh(src, "")
	var am := ArrayMesh.new()
	if mi != null:
		for si in mi.mesh.get_surface_count():
			var a := mi.mesh.surface_get_arrays(si)
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			for k in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_INDEX]:
				arrays[k] = a[k]
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	src.free()
	return am


static func material(d: Dictionary) -> ShaderMaterial:
	if _shader == null:
		_shader = load("res://shaders/vat.gdshader")
	var info: Dictionary = d.info
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("vat_hi", d.hi)
	mat.set_shader_parameter("vat_lo", d.lo)
	mat.set_shader_parameter("vat_n", d.n)
	mat.set_shader_parameter("pos_min", Vector3(info.bounds_min[0], info.bounds_min[1], info.bounds_min[2]))
	mat.set_shader_parameter("pos_size", Vector3(info.bounds_size[0], info.bounds_size[1], info.bounds_size[2]))
	mat.set_shader_parameter("tex_w", float(info.width))
	mat.set_shader_parameter("rpf", float(info.rpf))
	mat.set_shader_parameter("clips", d.clip_arr)
	return mat


## Einzelne Figur für Vorschauen (Monsterbuch): ein MultiMesh mit einer Instanz, die einen Clip in Schleife zeigt.
static func preview(key: String, clip := "idle", tint := Color.WHITE) -> Node3D:
	var d := data(key)
	var root := Node3D.new()
	if d.is_empty():
		return root
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = d.mesh
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform3D.IDENTITY)
	mm.set_instance_color(0, Color(tint.r, tint.g, tint.b, 0.0))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = material(d)
	var hg: float = d.height
	mi.custom_aabb = AABB(Vector3(-hg - 1.0, -1, -hg - 1.0), Vector3(2 * hg + 2.0, hg + 2, 2 * hg + 2.0))
	root.add_child(mi)
	var ci := int(d.clips.get(clip, 0))
	var dur: float = d.dur[ci]
	mm.set_instance_custom_data(0, Color(ci, 0, 0, 0))
	root.tree_entered.connect(func():
		var tw := root.create_tween().set_loops()
		tw.tween_method(func(ph: float): mm.set_instance_custom_data(0, Color(ci, ph, 0, 0)), 0.0, 1.0, dur))
	return root
