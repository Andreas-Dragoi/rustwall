extends Node3D
## Testszene für die Figuren-Animationen (res://scenes/anim_test.tscn): Held läuft über ein Schachbrett (1-m-Felder).
## Tasten: Pfeile/WASD = Laufrichtung relativ zur Blickrichtung, Q/E = langsamer/schneller, Z = Zeitlupe x0,25,
##         Leertaste = zielen an/aus, F = Schuss, R = nachladen, C = nächster Clip, H = nächster Held, V = Fahrzeug-Sitz.
## Für Bilder (immer mit --selftest starten):
##   --kind=<held> --weapon=<waffe> --clip=<name> [--n=8]      Reihe: derselbe Clip zu n Zeitpunkten
##   --move=x,y [--aim=1] [--n=8]                              Reihe: Lauf (m/s, x seitwärts, y vorwärts) als Zeitreihe
##   --ride=quad|bike|car|hover   --cam=front|side|iso|back    --shot=<datei.png>   --hold=1 (Clip halten)

const D = preload("res://src/data.gd")
const Humanoid = preload("res://src/humanoid.gd")
const Models = preload("res://src/models.gd")
const MK = preload("res://src/mk.gd")

var cam: Camera3D
var hero: Node3D
var kind := "jona"
var weapon := "j_rifle"
var move := Vector2.ZERO
var slow := false
var clips: Array = []
var clip_i := -1
var label: Label


func _ready() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("9CC4E8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("BFD4F0")
	env.ambient_light_energy = 0.8
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -140, 0)
	fill.light_energy = 0.5
	add_child(fill)
	_board()
	cam = Camera3D.new()
	cam.fov = 30.0
	add_child(cam)
	kind = G.arg("kind", "jona")
	weapon = G.arg("weapon", String(D.HEROES[kind].weapons[0]) if D.HEROES.has(kind) else "")
	clips = Humanoid.library().get_animation_list()
	if G.arg("shot") != "":
		_sheet()
		return
	hero = _figure(kind, weapon)
	label = Label.new()
	label.position = Vector2(20, 20)
	label.add_theme_font_size_override("font_size", 28)
	var cl := CanvasLayer.new()
	add_child(cl)
	cl.add_child(label)
	_place_cam("iso", Vector3.ZERO, 9.0)


func _board() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-30, 30):
		for z in range(-30, 30):
			var c := Color("C9D2B0") if (x + z) % 2 == 0 else Color("7E9A62")
			st.set_color(c)
			st.set_normal(Vector3.UP)
			var a := Vector3(x, 0, z)
			for v in [a, a + Vector3(1, 0, 0), a + Vector3(1, 0, 1), a, a + Vector3(1, 0, 1), a + Vector3(0, 0, 1)]:
				st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	mi.material_override = m
	add_child(mi)


func _figure(k: String, w: String) -> Node3D:
	var h: Node3D = Humanoid.new()
	add_child(h)
	h.build({"kind": k})
	h.scale = Vector3.ONE * D.CHAR_SCALE
	if w != "" and D.WEAPONS.has(w):
		h.set_weapon(Models.weapon(w), float(D.WEAPONS[w].len))
	return h


func _place_cam(view: String, center: Vector3, dist: float) -> void:
	var dir := Vector3(0.75, 0.55, 1.0)
	match view:
		"front":
			dir = Vector3(0, 0.25, 1)
		"back":
			dir = Vector3(0, 0.25, -1)
		"side":
			dir = Vector3(1, 0.15, 0)
		"top":
			dir = Vector3(0.01, 1, 0.3)
		"high":
			dir = Vector3(0.0, 0.4, 1.0)
	cam.position = center + dir.normalized() * dist
	cam.look_at(center, Vector3.UP)


## Bildreihen: je Clip (Komma-Liste) eine Reihe mit n Figuren, jede zu einem späteren Zeitpunkt desselben Ablaufs.
func _sheet() -> void:
	var n := int(G.arg("n", "8"))
	var rows: Array = Array(G.arg("clip").split(",")) if G.arg("clip") != "" else [""]
	var mv := Vector2.ZERO
	if G.arg("move") != "":
		var p := G.arg("move").split(",")
		mv = Vector2(float(p[0]), float(p[1]))
	var gap := float(G.arg("gap", "2.1"))
	var rgap := float(G.arg("rgap", "2.6"))
	var side := G.arg("cam", "iso") == "side"
	for ri in rows.size():
		var clip: String = rows[ri]
		var total := float(G.arg("t", "0"))
		if total <= 0.0:
			total = Humanoid.clip_len(clip) if Humanoid.AD.CLIPS.has(clip) else (1.0 / maxf(Humanoid.cycle_rate(mv.length(), mv), 0.1) if mv != Vector2.ZERO else 2.0)
		for i in n:
			var h := _figure(kind, weapon)
			var c := (i - (n - 1) * 0.5) * gap
			var rz := (ri - (rows.size() - 1) * 0.5) * rgap
			var base := Vector3(rz, 0, c) if side else Vector3(c, 0, rz)
			h.position = base
			h.aiming = G.arg("aim") == "1"
			h.ride = G.arg("ride")
			h.carrying = G.arg("carry") == "1"
			h.rotation.y = deg_to_rad(float(G.arg("yaw", "0" if side else "35")))
			var t_end := total * float(i) / float(maxi(n - 1, 1)) if G.arg("same") != "1" else total
			var warm := 0.6 if (mv != Vector2.ZERO or h.aiming or h.ride != "") else 0.0
			var t := -warm
			var started := false
			var dtt := 1.0 / 120.0
			while t < t_end - 0.0001 or not started:
				if t >= 0.0 and not started:
					started = true
					match clip:
						"", "none":
							pass
						"kick":
							h.kick()
						"reload":
							h.reload(total)
						"hop":
							h.hop()
						"die":
							h.die()
						_:
							if not h.play(clip, G.arg("hold") == "1"):
								h.play(clip.get_slice("_", 1) + "_" + clip.get_slice("_", 2), false) if clip.count("_") >= 2 else null
					h.position = base
				if mv != Vector2.ZERO:
					h.speed_mps = mv.length()
					h.move_amount = mv.length() / 6.4
					h.move_dir = mv.normalized()
					if G.arg("still") != "1":
						h.position += h.global_transform.basis.orthonormalized() * Vector3(mv.x, 0, mv.y) * dtt
				if G.arg("look") != "":
					var lp := G.arg("look").split(",")
					h.look_target = h.global_position + Vector3(float(lp[0]), float(lp[1]), float(lp[2]))
				h._half = false
				h._lod_t = 9.0
				h.tick(dtt)
				t += dtt
			if G.arg("still") == "1" or mv != Vector2.ZERO:
				h.position = base
	var width := gap * n + 0.6
	var asp := float(get_viewport().get_visible_rect().size.x) / float(get_viewport().get_visible_rect().size.y)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = float(G.arg("size", str(maxf(width / asp, 3.6 + (rows.size() - 1) * rgap * 0.5))))
	_place_cam(G.arg("cam", "high"), Vector3(0, 1.25, 0), 30.0)
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(G.arg("shot"))
	print("SHOT ", G.arg("shot"))
	get_tree().quit()


func _process(dt: float) -> void:
	if hero == null:
		return
	var h := hero
	h.speed_mps = move.length()
	h.move_amount = move.length() / 6.4
	h.move_dir = move.normalized() if move != Vector2.ZERO else Vector2(0, 1)
	h.position += h.global_transform.basis.orthonormalized() * Vector3(move.x, 0, move.y) * dt
	if absf(h.position.x) > 12.0 or absf(h.position.z) > 12.0:
		h.position = Vector3.ZERO
	h.look_target = h.global_position + h.global_transform.basis.z.normalized() * 8.0 + Vector3(0, 0.6, 0) if h.aiming else null
	h.tick(dt)
	_place_cam("iso", h.position + Vector3(0, 1.0, 0), 9.0)
	label.text = "%s  %s   Tempo %.1f m/s  Richtung (%.0f, %.0f)   Zeitlupe %s\nSchrittzyklen/s %.2f   Clip: %s" % [kind, weapon, move.length(), signf(move.x), signf(move.y), "x0,25" if slow else "aus", Humanoid.cycle_rate(move.length(), move), String(clips[clip_i]) if clip_i >= 0 else "-"]


func _unhandled_key_input(ev: InputEvent) -> void:
	if hero == null or not ev.pressed or ev.echo:
		return
	var sp := maxf(move.length(), 0.0)
	match ev.keycode:
		KEY_UP, KEY_W:
			move = Vector2(0, 1) * maxf(sp, 3.0)
		KEY_DOWN, KEY_S:
			move = Vector2(0, -1) * maxf(sp, 3.0)
		KEY_LEFT, KEY_A:
			move = Vector2(-1, 0) * maxf(sp, 3.0)
		KEY_RIGHT, KEY_D:
			move = Vector2(1, 0) * maxf(sp, 3.0)
		KEY_X:
			move = Vector2.ZERO
		KEY_Q:
			move = move.normalized() * maxf(sp - 0.5, 0.0)
		KEY_E:
			move = (move.normalized() if move != Vector2.ZERO else Vector2(0, 1)) * minf(sp + 0.5, 8.0)
		KEY_Z:
			slow = not slow
			Engine.time_scale = 0.25 if slow else 1.0
		KEY_SPACE:
			hero.aiming = not hero.aiming
		KEY_F:
			hero.kick()
		KEY_R:
			hero.reload(1.8)
		KEY_V:
			hero.ride = "quad" if hero.ride == "" else ""
		KEY_C:
			clip_i = (clip_i + 1) % clips.size()
			hero.play(String(clips[clip_i]))
		KEY_H:
			var i := D.HERO_ORDER.find(kind)
			kind = D.HERO_ORDER[(i + 1) % D.HERO_ORDER.size()]
			weapon = String(D.HEROES[kind].weapons[0])
			hero.queue_free()
			hero = _figure(kind, weapon)
