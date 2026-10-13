extends RefCounted
## Paket Q (Kapitel 3.2): PC und Controller.
##  - Tastenbelegung ändern (gespeichert je Gerät in device_cfg), Standard wiederherstellen, Tausch bei Doppelbelegung.
##  - Fenster: Fenster / Vollbild / randlos, Auflösung im Fenster, VSync, Bildratenbegrenzung (nur PC).
##  - Gamepad: rechter Stick zielt (Aktionen aim_*), Select/Back = Gebäude in der Nähe wählen bzw. nächste Welle,
##    Menüs mit Fokus-Navigation (Steuerkreuz/linker Stick, A bestätigt, B schließt) – erledigt der Knoten PadNav.
## Einstieg: G._ready() ruft setup(G) auf.

const Dev = preload("res://src/device_cfg.gd")

## Aktionen, die sich umbelegen lassen: [Aktion, Name, Standardtaste]
const ACTIONS := [
	["move_up", "Nach oben laufen", KEY_W], ["move_down", "Nach unten laufen", KEY_S], ["move_left", "Nach links laufen", KEY_A],
	["move_right", "Nach rechts laufen", KEY_D], ["skill1", "Fähigkeit 1", KEY_Q], ["skill2", "Fähigkeit 2", KEY_E], ["ult", "Spezialfähigkeit", KEY_R],
	["cmd", "Kommandanten-Fähigkeit", KEY_F], ["dodge", "Ausweichen", KEY_SPACE], ["use", "Fahrzeug ein/aus", KEY_T],
	["next_wave", "Nächste Welle rufen", KEY_N], ["pause", "Pause", KEY_ESCAPE],
]
## Gamepad-Belegung (fest) für die Anzeige in den Einstellungen
const PAD_HELP := [["Linker Stick", "Laufen (in Menüs: Auswahl bewegen)"], ["Rechter Stick", "Zielen und schießen"],
	["A", "Ausweichen · in Menüs: bestätigen"], ["B", "Fahrzeug ein/aus · in Menüs: zurück"], ["X / Y", "Fähigkeit 1 / 2"],
	["RB", "Spezialfähigkeit"], ["LB", "Kommandanten-Fähigkeit"], ["Start", "Pause"],
	["Select", "Basis: Gebäude in der Nähe wählen und Menü bedienen · Flut: nächste Welle"], ["Steuerkreuz", "In Menüs: Auswahl bewegen"]]
const WIN_MODES := [["Fenster", "window"], ["Vollbild", "full"], ["Randlos", "borderless"]]
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
const FPS_CAPS := [30, 60, 120, 144, 0]

static var nav: Node = null


static func setup(g: Node) -> void:
	_aim_actions()
	apply_keys()
	if not G.selftest and G.autotest == "" and is_pc():
		apply_window()
	nav = preload("res://src/pad_nav.gd").new()
	nav.name = "PadNav"
	g.add_child.call_deferred(nav)


## PC: Windows, macOS, Linux (nicht Handy, nicht Browser)
static func is_pc() -> bool:
	return OS.has_feature("pc") and not OS.has_feature("web") and not OS.has_feature("mobile")


# ================================================================= Tastenbelegung
static func _aim_actions() -> void:
	for a in [["aim_left", JOY_AXIS_RIGHT_X, -1.0], ["aim_right", JOY_AXIS_RIGHT_X, 1.0], ["aim_up", JOY_AXIS_RIGHT_Y, -1.0], ["aim_down", JOY_AXIS_RIGHT_Y, 1.0]]:
		if InputMap.has_action(a[0]):
			InputMap.erase_action(a[0])
		InputMap.add_action(a[0], 0.2)
		var e := InputEventJoypadMotion.new()
		e.axis = a[1]
		e.axis_value = a[2]
		InputMap.action_add_event(a[0], e)
	# Select/Back: nächste Welle (Flut) bzw. Gebäude wählen (Basis, siehe PadNav)
	if InputMap.has_action("next_wave"):
		var b := InputEventJoypadButton.new()
		b.button_index = JOY_BUTTON_BACK
		InputMap.action_add_event("next_wave", b)


static func default_key(action: String) -> int:
	for a in ACTIONS:
		if a[0] == action:
			return int(a[2])
	return 0


## Eigene Belegung: {Aktion: physische Taste}; fehlt eine Aktion, gilt die Standardtaste.
static func keymap() -> Dictionary:
	var m = Dev.get_v("keys", {})
	return m if m is Dictionary else {}


static func key_of(action: String) -> int:
	return int(keymap().get(action, default_key(action)))


## Legt die Taste fest. Ist sie schon an eine andere Aktion vergeben, tauschen beide.
static func set_key(action: String, key: int) -> String:
	var m := keymap().duplicate()
	var old := key_of(action)
	var swapped := ""
	for a in ACTIONS:
		var other: String = a[0]
		if other != action and key_of(other) == key:
			m[other] = old
			swapped = String(a[1])
	m[action] = key
	Dev.set_v("keys", m)
	apply_keys()
	return swapped


static func reset_keys() -> void:
	Dev.erase("keys")
	apply_keys()


## Ersetzt in jeder umbelegbaren Aktion die erste Taste (die Standardtaste) durch die eigene Wahl.
## Zweittasten (Pfeiltasten, P) und Gamepad-Belegungen bleiben erhalten.
static func apply_keys() -> void:
	for a in ACTIONS:
		var act: String = a[0]
		if not InputMap.has_action(act):
			continue
		var want := key_of(act)
		var first: InputEventKey = null
		for e in InputMap.action_get_events(act):
			if e is InputEventKey:
				first = e
				break
		if first == null:
			var ne := InputEventKey.new()
			ne.physical_keycode = want as Key
			InputMap.action_add_event(act, ne)
		elif int(first.physical_keycode) != want:
			InputMap.action_erase_event(act, first)
			var ne2 := InputEventKey.new()
			ne2.physical_keycode = want as Key
			# vorn einfügen: alle Ereignisse neu aufbauen
			var rest: Array = InputMap.action_get_events(act)
			InputMap.action_erase_events(act)
			InputMap.action_add_event(act, ne2)
			for e2 in rest:
				InputMap.action_add_event(act, e2)


static func key_name(key: int) -> String:
	if key == 0:
		return "–"
	var lab := key
	if DisplayServer.get_name() != "headless" and not OS.has_feature("web"):
		lab = int(DisplayServer.keyboard_get_label_from_physical(key as Key))     # Tastaturbelegung (z. B. QWERTZ)
	var s := OS.get_keycode_string((lab if lab != 0 else key) as Key)
	match s:
		"Space":
			return "Leertaste"
		"Escape":
			return "Esc"
	return s


# ================================================================= Fenster (PC)
static func win_mode() -> String:
	return String(Dev.get_v("win_mode", "window"))


static func resolution() -> Vector2i:
	var r = Dev.get_v("win_res", Vector2i(1280, 720))
	return r if r is Vector2i else Vector2i(1280, 720)


static func vsync() -> bool:
	return bool(Dev.get_v("vsync", true))


## Bildratenbegrenzung am PC: -1 = nicht eingestellt (Spiel entscheidet wie bisher), 0 = unbegrenzt.
static func fps_cap() -> int:
	if not is_pc():
		return -1
	return int(Dev.get_v("fps_cap", -1))


static func set_window(mode: String, res := Vector2i.ZERO) -> void:
	Dev.set_v("win_mode", mode)
	if res != Vector2i.ZERO:
		Dev.set_v("win_res", res)
	apply_window()


static func set_vsync(on: bool) -> void:
	Dev.set_v("vsync", on)
	apply_window()


static func set_fps_cap(v: int) -> void:
	Dev.set_v("fps_cap", v)


## Wendet Fenstermodus, Auflösung und VSync an (nur PC, nicht in Tests).
static func apply_window() -> void:
	if not is_pc() or DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync() else DisplayServer.VSYNC_DISABLED)
	if not Dev.has("win_mode"):
		return
	var scr := DisplayServer.window_get_current_screen()
	match win_mode():
		"full":
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		"borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			DisplayServer.window_set_position(DisplayServer.screen_get_position(scr))
			DisplayServer.window_set_size(DisplayServer.screen_get_size(scr))
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			var ss := DisplayServer.screen_get_size(scr)
			var r := resolution()
			r = Vector2i(mini(r.x, ss.x), mini(r.y, ss.y))
			DisplayServer.window_set_size(r)
			DisplayServer.window_set_position(DisplayServer.screen_get_position(scr) + (ss - r) / 2)


## Auflösungen, die auf diesen Bildschirm passen
static func resolutions() -> Array:
	var ss := Vector2i(3840, 2160)
	if DisplayServer.get_name() != "headless":
		ss = DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	var out: Array = []
	for r in RESOLUTIONS:
		if r.x <= ss.x and r.y <= ss.y:
			out.append(r)
	if out.is_empty():
		out.append(RESOLUTIONS[0])
	return out
