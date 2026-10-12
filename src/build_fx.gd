extends RefCounted
## Bau-Animation (Paket G2, Kapitel 7.2): Ist ein Gebäude fertig, fliegen Bauteile (Bretter, Ziegel, Balken, Bleche, Rohre,
## Kisten aus models/fx_build_parts.glb) nacheinander von oben heran, schlagen mit Staubwolke und Hammerschlag auf
## und verschwinden im fertigen Gebäude. Danach ploppt das Gebäude kurz auf.

const D = preload("res://src/data.gd")
const Models = preload("res://src/models.gd")

static var _pieces: Array = []       # Meshes der Bauteile (einmal geladen)


static func _load() -> void:
	if not _pieces.is_empty() or not Models.has_glb("fx_build_parts"):
		return
	var root: Node = Models.glb("fx_build_parts")
	for c in root.find_children("*", "MeshInstance3D", true, false):
		_pieces.append((c as MeshInstance3D).mesh)
	root.free()


static func play(s) -> void:
	if s == null or not is_instance_valid(s) or s.model == null or not s.is_inside_tree():
		return
	_load()
	var def: Dictionary = D.BUILDINGS.get(String(s.key), {})
	if def.get("cat", "") == "deco" and int(def.get("deco", D.DECO_POINTS_OLD.get(String(s.key), 0))) > 0:
		P.toast.emit("Deko-Punkte: %d – Produktion +%d %%" % [P.deco_points(), int(round(P.deco_bonus() * 100.0))])
	if _pieces.is_empty() or String(s.key) == "wall":
		return                                              # Mauerstücke werden in Reihen fertig: keine Teile-Flut
	var rng := RandomNumberGenerator.new()
	rng.seed = int(s.mid.x * 13.0 + s.mid.y * 7.0) + Time.get_ticks_msec()
	var top: float = maxf(Models.height(s.model), 0.8)
	var rad: float = float(s.radius)
	var n: int = clampi(int(rad * 3.0), 4, 12)
	var mat = load("res://src/mk.gd").mat_lin()
	for i in n:
		var m := MeshInstance3D.new()
		m.mesh = _pieces[rng.randi() % _pieces.size()]
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var target := Vector3(rng.randf_range(-0.6, 0.6) * rad, rng.randf_range(0.35, 0.95) * top, rng.randf_range(-0.6, 0.6) * rad)
		var start := target + Vector3(rng.randf_range(-5.0, 5.0), rng.randf_range(7.0, 11.0), rng.randf_range(-5.0, 5.0))
		m.position = start
		m.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		m.scale = Vector3.ONE * clampf(rad * 0.45, 0.6, 1.4)
		m.visible = false
		s.add_child(m)
		var tw: Tween = m.create_tween()
		tw.tween_interval(0.09 * i)
		tw.tween_callback(func(): m.visible = true)
		tw.set_parallel(true)
		tw.tween_property(m, "position", target, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(m, "rotation", Vector3(0, rng.randf() * TAU, 0), 0.5)
		tw.set_parallel(false)
		tw.tween_callback(func():
			if G.fx != null and is_instance_valid(m):
				var gp: Vector3 = m.global_position
				G.fx.puff(Vector3(gp.x, maxf(gp.y - 0.2, 0.2), gp.z), Color(0.82, 0.76, 0.66), 6, 1.2)
				Sfx.play_at("build_thunk", gp, -12.0, rng.randf_range(0.85, 1.2), 0.05))
		tw.tween_interval(0.18)
		tw.tween_property(m, "scale", Vector3.ZERO, 0.22)
		tw.tween_callback(m.queue_free)
	# zum Schluss eine Staubwolke am Boden und ein Ploppen
	var tw2: Tween = s.create_tween()
	tw2.tween_interval(0.09 * n + 0.55)
	tw2.tween_callback(func():
		if is_instance_valid(s):
			if G.fx != null:
				for k in 6:
					var a := TAU * k / 6.0
					G.fx.puff(s.global_position + Vector3(cos(a) * rad, 0.3, sin(a) * rad), Color(0.8, 0.74, 0.62), 6, 1.4)
			s.pop()
			Sfx.play_at("build_done_thud", s.global_position, -8.0))
