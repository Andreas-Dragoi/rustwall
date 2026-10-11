extends SubViewportContainer
## Kleine 3D-Vorschau (Held, Fahrzeug, Kiste) mit eigener Welt. Dreht sich langsam,
## lässt sich mit Finger oder Maus drehen. Rechnet nur, solange der Knoten im Baum ist.

const D = preload("res://src/data.gd")
const Humanoid = preload("res://src/humanoid.gd")
const Models = preload("res://src/models.gd")

var sig := ""                      # Kennung des gezeigten Inhalts (zum Wiederverwenden)
var vp: SubViewport
var pivot: Node3D
var cam: Camera3D
var human: Node3D
var spin := 0.5
var _drag := false
var _hold := 0.0
var _dist := 3.6
var _height := 0.85
var _base_aspect := 0.75           # schmaler als das: Kamera rückt weiter weg, damit nichts abgeschnitten wird


func _init() -> void:
	stretch = true
	custom_minimum_size = Vector2(320, 400)
	mouse_filter = Control.MOUSE_FILTER_STOP
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.size = Vector2i(420, 520)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("BFD4F0")
	env.ambient_light_energy = 0.75
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 32, 0)
	sun.light_energy = 1.25
	sun.light_color = Color("FFF3DC")
	vp.add_child(sun)
	cam = Camera3D.new()
	cam.fov = 34.0
	vp.add_child(cam)
	pivot = Node3D.new()
	vp.add_child(pivot)
	_aim(3.6, 0.85)


func _aim(dist: float, height: float, base_aspect := 0.75) -> void:
	_dist = dist
	_height = height
	_base_aspect = base_aspect
	_apply_cam()


func _apply_cam() -> void:
	var d := _dist
	if size.x > 1.0 and size.y > 1.0:
		var aspect := size.x / size.y
		if aspect < _base_aspect:
			d *= _base_aspect / aspect
	cam.position = Vector3(0, _height + d * 0.16, d)
	cam.look_at_from_position(cam.position, Vector3(0, _height, 0), Vector3.UP)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and cam != null:
		_apply_cam()


func _clear() -> void:
	human = null
	for c in pivot.get_children():
		pivot.remove_child(c)
		c.queue_free()


func show_hero(key: String, tier: int, weapon_key: String) -> void:
	_clear()
	var def: Dictionary = D.HEROES[key]
	var h: Node3D = Humanoid.new()
	pivot.add_child(h)
	h.build({"helm": def.color, "suit": def.suit, "kind": key, "tier": tier})
	if weapon_key != "" and D.WEAPONS.has(weapon_key):
		h.set_weapon(Models.weapon(weapon_key), float(D.WEAPONS[weapon_key].len))
	h.aiming = true
	h.tick(0.016)
	human = h
	pivot.rotation.y = 0.45
	_aim(4.3, 0.92, 0.72)


func show_model(node: Node3D, dist: float, height: float) -> void:
	_clear()
	pivot.add_child(node)
	pivot.rotation.y = 0.7
	_aim(dist, height, 1.3)


func cheer() -> void:
	if human:
		human.cheer()


func _process(dt: float) -> void:
	if human:
		human.tick(dt)
	if _drag:
		return
	if _hold > 0.0:
		_hold -= dt
	else:
		pivot.rotation.y += dt * spin


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_drag = ev.pressed
		_hold = 1.5
	elif ev is InputEventMouseMotion and _drag:
		pivot.rotation.y += ev.relative.x * 0.012
