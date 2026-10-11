extends Node
## Globaler Zugriffspunkt (Autoload "G"): Verweise auf die laufende Welt und ihre Systeme,
## einheitliche Eingabe für Touch, Tastatur, Maus und Gamepad, Testschalter.

const D = preload("res://src/data.gd")

# Verweise, die die laufende Welt (Basis oder Expedition) setzt
var main: Node
var game: Node3D                  # base_world.gd oder expedition.gd
var player: Node3D                # hero.gd
var horde: Node3D
var coins: Node3D
var fx: Node3D
var field: RefCounted
var cam: Node3D
var hud: CanvasLayer

# Eingabe
var is_touch := false
var touch_move := Vector2.ZERO
var touch_sprint := false
signal input_mode_changed
signal skill_pressed(slot: int)   # 0 = Fähigkeit 1, 1 = Fähigkeit 2, 2 = Spezial, 3 = Kommandant
signal dodge_pressed
signal use_pressed
signal next_wave_pressed
signal pause_pressed

# Testbetrieb (Kommandozeile hinter "--")
var autotest := ""                # "flood" | "exp" | "base"
var selftest := false
var shots_dir := ""
var test_speed := 6.0
var test_view := ""
var test_shots: Array = []
var test_args := {}
var force_touch := false

## Admin-Schalter (Taste - oder ,). Werden nicht gespeichert.
var cheat := {}


func ch(key: String) -> bool:
	return cheat.get(key, false)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autotest="):
			autotest = a.substr(11)
		elif a == "--selftest":
			selftest = true
		elif a.begins_with("--shots="):
			shots_dir = a.substr(8)
		elif a.begins_with("--fast="):
			test_speed = float(a.substr(7))
		elif a.begins_with("--view="):
			test_view = a.substr(7)
		elif a == "--touch":
			force_touch = true
		elif a.begins_with("--at="):
			for part in a.substr(5).split(","):
				test_shots.append(float(part))
		elif a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=")
			test_args[kv[0]] = kv[1]
	if autotest != "":
		Engine.max_physics_steps_per_frame = 40
	_setup_actions()
	is_touch = (DisplayServer.is_touchscreen_available() and (OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android"))) or force_touch


func arg(key: String, def: String = "") -> String:
	return String(test_args.get(key, def))


func _setup_actions() -> void:
	_act("move_left", [KEY_A, KEY_LEFT], [], [[JOY_AXIS_LEFT_X, -1.0]])
	_act("move_right", [KEY_D, KEY_RIGHT], [], [[JOY_AXIS_LEFT_X, 1.0]])
	_act("move_up", [KEY_W, KEY_UP], [], [[JOY_AXIS_LEFT_Y, -1.0]])
	_act("move_down", [KEY_S, KEY_DOWN], [], [[JOY_AXIS_LEFT_Y, 1.0]])
	_act("dodge", [KEY_SPACE], [JOY_BUTTON_A], [])
	_act("skill1", [KEY_Q], [JOY_BUTTON_X], [])
	_act("skill2", [KEY_E], [JOY_BUTTON_Y], [])
	_act("ult", [KEY_R], [JOY_BUTTON_RIGHT_SHOULDER], [])
	_act("cmd", [KEY_F], [JOY_BUTTON_LEFT_SHOULDER], [])
	_act("use", [KEY_T], [JOY_BUTTON_B], [])
	_act("next_wave", [KEY_N], [], [])
	_act("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START], [])


func _act(action: String, keys: Array, buttons: Array, axes: Array) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, 0.25)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for b in buttons:
		var e2 := InputEventJoypadButton.new()
		e2.button_index = b
		InputMap.action_add_event(action, e2)
	for ax in axes:
		var e3 := InputEventJoypadMotion.new()
		e3.axis = ax[0]
		e3.axis_value = ax[1]
		InputMap.action_add_event(action, e3)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_set_touch(true)
	elif event is InputEventKey or event is InputEventJoypadButton:
		_set_touch(false)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		_set_touch(false)
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F11:
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if event.is_action_pressed("skill1"):
		skill_pressed.emit(0)
	elif event.is_action_pressed("skill2"):
		skill_pressed.emit(1)
	elif event.is_action_pressed("ult"):
		skill_pressed.emit(2)
	elif event.is_action_pressed("cmd"):
		skill_pressed.emit(3)
	elif event.is_action_pressed("dodge"):
		dodge_pressed.emit()
	elif event.is_action_pressed("use"):
		use_pressed.emit()
	elif event.is_action_pressed("next_wave"):
		next_wave_pressed.emit()
	elif event.is_action_pressed("pause"):
		pause_pressed.emit()


func _set_touch(v: bool) -> void:
	if force_touch or OS.has_feature("web_ios") or OS.has_feature("web_android"):
		v = true          # Handy-Browser: Browser erzeugt nach Berührungen zusätzlich Mausereignisse
	if v != is_touch:
		is_touch = v
		if not v:
			touch_move = Vector2.ZERO
			touch_sprint = false
		input_mode_changed.emit()


## Bewegungswunsch in Bildschirm-Achsen (x rechts, y unten), Länge 0..1.
func move_vector() -> Vector2:
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if touch_move.length_squared() > v.length_squared():
		v = touch_move
	return v.limit_length(1.0)


func vibrate(ms: int) -> void:
	if is_touch and P.d.settings.get("vibrate", true):
		Input.vibrate_handheld(ms)


func quality() -> int:
	# Handy-Browser: wenig Speicher – „Niedrig“, solange der Spieler nichts anderes gewählt hat
	if web_mobile() and not P.d.settings.get("quality_user", false):
		return 0
	return clampi(int(P.d.settings.get("quality", 1)), 0, 2)


func web_mobile() -> bool:
	return OS.has_feature("web_ios") or OS.has_feature("web_android")


func max_alive() -> int:
	return int(D.MAX_ALIVE[quality()])


## Wendet Grafik-Einstellungen an (Auflösungs-Skalierung, Bildrate).
func apply_quality() -> void:
	var vp := get_viewport()
	var q := quality()
	vp.scaling_3d_scale = [0.7, 0.85, 1.0][q]
	if web_mobile() or arg("s3d") != "":
		# Handy-Browser: Oberfläche in voller Bildschirmschärfe, 3D-Welt mit etwa 1300 Bildpunkten Breite (spart Speicher)
		var w: float = maxf(float(DisplayServer.window_get_size().x), 1.0)
		var target: float = [1300.0, 1600.0, 2000.0][q]
		vp.scaling_3d_scale = clampf(target / w, 0.35, 1.0) if arg("s3d") == "" else float(arg("s3d"))
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_2X][q]
	Engine.max_fps = 60 if P.d.settings.get("fps60", not web_mobile()) else 30
	if autotest != "":
		Engine.max_fps = 0
