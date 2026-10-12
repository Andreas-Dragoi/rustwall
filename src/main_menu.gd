extends CanvasLayer
## Hauptmenü und Intro.
## Hinter dem Menü läuft die eigene Basis (Kamera kreist langsam um den Bunker).
## Städte: weiterspielen, wechseln, neu anlegen (mit Bunkername), löschen (mit Rückfrage).
## Intro: fünf kurze Bilder mit Kamerafahrt über die Basis, jederzeit überspringbar.

const D = preload("res://src/data.gd")
const UI = preload("res://src/ui.gd")

signal play_pressed

const INTRO := [
	["Vor vielen Jahren kam die Flut.", "Seitdem kriecht jede Woche etwas aus den acht Gebieten.", Vector3(0, 0, 0), -0.6, 0.15, 46.0],
	["Schleimlinge, Untote, Waldgeister, Dämonen …", "Sie wollen nur eines: deinen Bunker.", Vector3(14, 0, 10), 0.4, 0.0, 30.0],
	["Hinter starken Mauern ist man sicher.", "Bewohner bauen, sammeln und reparieren für dich.", Vector3(-10, 0, 12), 1.1, -0.1, 26.0],
	["Draußen warten Rohstoffe und Außenbasen.", "Sammle, trag alles heim und erobere die Gebiete.", Vector3(8, 0, -14), 1.8, 0.05, 34.0],
	["Das ist deine Stadt:", "", Vector3(0, 0, 0), 2.6, 0.0, 24.0],
]
const INTRO_STEP := 3.6

var _root: Control
var _menu: Control
var _panel: Control                  # rechte Tafel (Städte, Neue Stadt)
var _title: Label
var _t := 0.0
var _intro_i := -1
var _intro_t := 0.0
var _intro_root: Control
var _cap1: Label
var _cap2: Label
var _bars: Array = []
var _name_edit: LineEdit
var _msg: Label
var _confirm_slot := -1
var is_intro := false


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UI.theme()
	add_child(_root)


# ================================================================= Menü
func show_menu() -> void:
	is_intro = false
	visible = true
	_set_game_ui(false)
	UI.clear(_root)
	_intro_root = null
	# linke Abdunklung als Verlauf, rechts bleibt die Basis sichtbar
	var shade := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.06, 0.14, 0.92))
	g.set_color(1, Color(0.02, 0.06, 0.14, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.25, 0)
	gt.fill_to = Vector2(0.75, 0)
	shade.texture = gt
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)

	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 70 if side == "left" else 50)
	_root.add_child(m)
	var row := UI.hbox(40)
	m.add_child(row)
	_menu = UI.vbox(18)
	_menu.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_menu.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_menu)

	_title = UI.label("RUSTWALL", 128, UI.GOLD)
	_title.add_theme_constant_override("outline_size", 28)
	_title.add_theme_color_override("font_outline_color", Color("0B1B33"))
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_title.add_theme_constant_override("shadow_offset_y", 10)
	_menu.add_child(_title)
	var sub := UI.label("Bau deinen Bunker. Halte die Mauer. Überlebe die Flut.", 28, UI.WHITE, false)
	sub.add_theme_constant_override("outline_size", 8)
	sub.add_theme_color_override("font_outline_color", Color("0B1B33"))
	_menu.add_child(sub)
	_menu.add_child(UI.spacer(false, Vector2(0, 26)))

	var city := UI.hbox(12, [UI.pic("b_bunker_%d" % clampi(int((P.bunker_level() + 1) / 2), 1, 5), 64.0, "ui_shield"),
		UI.vbox(0, [UI.label(P.bunker_name(), 32, UI.GOLD), UI.label("%s · Stufe %d · Bunker %d" % [String(P.d.name), int(P.d.level), P.bunker_level()], 21, UI.TEXT, false)])])
	_menu.add_child(UI.pill(city, 18, 10))
	var b_play := _big("Spielen", _on_play, "green", "ui_play")
	b_play.name = "Play"
	_menu.add_child(b_play)
	_menu.add_child(_big("Städte", func():
		_confirm_slot = -1
		_show_cities(), "", "ui_map"))
	_menu.add_child(_big("Intro ansehen", func(): start_intro(), "dark", "ui_play"))
	_menu.add_child(_big("Optionen", func():
		visible = false                      # Menü ausblenden, sonst liegt es über den Optionen
		G.main.screens.open("settings"), "dark", "ui_gear"))
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		_menu.add_child(_big("Beenden", func():
			P.save()
			get_tree().quit(), "red", "ui_close"))
	var ver := UI.label("Version 3 · Mitspieler simuliert", 18, Color(1, 1, 1, 0.55), false)
	_menu.add_child(ver)

	_panel = UI.vbox(12)
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_panel)
	_root.add_child(preload("res://src/liveops_ui.gd").menu_banner(self))     # Paket L: Ereignis, Saison, Neuigkeiten (unten rechts)
	Music.set_mood("menu")


func _big(t: String, cb: Callable, kind: String, ic: String) -> Button:
	var b := UI.button(t, cb, kind, 34, ic)
	b.custom_minimum_size = Vector2(500, 84)
	return b


func _on_play() -> void:
	UI.sfx("ui_claim", "", -8.0)
	if not bool(P.d.get("intro_seen", true)):
		start_intro()
		return
	hide_menu()


func hide_menu() -> void:
	visible = false
	is_intro = false
	UI.clear(_root)
	_set_game_ui(true)
	var w = G.main.world
	if w != null and w.cam != null:
		w.cam.yaw_off = 0.0
		w.cam.pitch_off = 0.0
		w.cam.override_target = null
		w.cam.dist = 26.0 if G.is_touch else 29.0
	Music.set_mood("peace")
	play_pressed.emit()


func _set_game_ui(on: bool) -> void:
	G.main.hud.visible = on
	if G.main.pad != null:
		G.main.pad.visible = on
	G.main.set_meta("menu_open", not on)


# ================================================================= Städte
func _show_cities() -> void:
	UI.clear(_panel)
	var v := UI.vbox(12)
	v.add_child(UI.label("Deine Städte", 40, UI.GOLD))
	for e in P.city_list():
		v.add_child(_city_card(e))
	if P.free_slot() > 0:
		v.add_child(UI.sep())
		v.add_child(UI.label("Neue Stadt gründen", 30))
		_name_edit = LineEdit.new()
		_name_edit.placeholder_text = "Bunkername (3–20 Zeichen)"
		_name_edit.max_length = P.BUNKER_NAME_MAX
		_name_edit.custom_minimum_size = Vector2(420, 72)
		_name_edit.text = _suggest()
		_name_edit.text_submitted.connect(func(_t: String): _create())
		var dice := UI.button("⚄", func(): _name_edit.text = _suggest(), "dark", 30)
		dice.tooltip_text = "Namen vorschlagen"
		dice.custom_minimum_size = Vector2(80, 72)
		var go := UI.button("Gründen", _create, "green", 28, "ui_check")
		go.custom_minimum_size = Vector2(0, 72)
		v.add_child(UI.hbox(10, [_name_edit, dice, go]))
		v.add_child(UI.label("Unter diesem Namen finden dich andere Spieler im Funkturm.", 19, UI.TEXT, false))
	else:
		v.add_child(UI.label("Höchstens %d Städte – lösche eine, um neu anzufangen." % P.MAX_CITIES, 21, UI.TEXT, false))
	_msg = UI.label("", 22, UI.RED)
	v.add_child(_msg)
	var close := UI.button("Zurück", func(): UI.clear(_panel), "dark", 26)
	close.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(close)
	_panel.add_child(UI.panel(UI.scroll(v, Vector2(760, 0)) if P.city_list().size() > 3 else v))


func _suggest() -> String:
	for i in 20:
		var nm := "%s%s" % [D.BUNKER_NAME_PARTS.pick_random(), D.BUNKER_NAME_ENDS.pick_random()]
		if P.check_bunker_name(nm, true) == "":
			return nm
	return ""


func _city_card(e: Dictionary) -> Control:
	var n := int(e.slot)
	var cur := bool(e.current)
	var info := UI.vbox(0, [UI.label(String(e.bunker_name), 28, UI.GOLD if cur else UI.WHITE),
		UI.label("%s · Stufe %d · Bunker %d%s" % [String(e.name), int(e.level), int(e.bunker), " · gerade aktiv" if cur else ""], 19, UI.TEXT, false)])
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := UI.hbox(12, [UI.pic("b_bunker_%d" % clampi(int((int(e.bunker) + 1) / 2), 1, 5), 60.0, "ui_shield"), info])
	if _confirm_slot == n:
		row.add_child(UI.label("Wirklich löschen?", 22, UI.RED))
		row.add_child(UI.button("Ja, löschen", func(): _delete(n), "red", 22))
		row.add_child(UI.button("Nein", func():
			_confirm_slot = -1
			_show_cities(), "dark", 22))
		row.add_child(UI.label("Für immer!", 18, UI.RED, false))
	else:
		if not cur:
			row.add_child(UI.button("Spielen", func(): _switch(n), "green", 24, "ui_play"))
			var del := UI.button("Löschen", func():
				_confirm_slot = n
				_show_cities(), "red", 22)
			row.add_child(del)
		else:
			row.add_child(UI.button("Spielen", hide_menu, "green", 24, "ui_play"))
	return UI.card(row, UI.NAVY_L if not cur else Color("24508F"), 12)


func _say(t: String) -> void:
	if _msg != null and is_instance_valid(_msg):
		_msg.text = t


func _create() -> void:
	var why: String = P.create_city(_name_edit.text)
	if why != "":
		_say(why)
		return
	UI.sfx("ui_claim", "", -6.0)
	G.main.goto_base()
	start_intro()


func _switch(n: int) -> void:
	var why: String = P.switch_city(n)
	if why != "":
		_say(why)
		return
	G.main.goto_base()
	show_menu()
	_show_cities()


func _delete(n: int) -> void:
	var why: String = P.delete_city(n)
	_confirm_slot = -1
	_show_cities()
	_say(why if why != "" else "Stadt gelöscht.")


# ================================================================= Intro
func start_intro() -> void:
	is_intro = true
	visible = true
	_set_game_ui(false)
	UI.clear(_root)
	_intro_root = Control.new()
	_intro_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_intro_root)
	_bars.clear()
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.anchor_left = 0.0
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if top else 1.0
		bar.anchor_bottom = 0.0 if top else 1.0
		bar.offset_bottom = 0.0
		bar.offset_top = 0.0
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_intro_root.add_child(bar)
		_bars.append(bar)
	var box := UI.vbox(10)
	box.anchor_left = 0.0
	box.anchor_right = 1.0
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_top = -280
	box.offset_bottom = -125
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cap1 = UI.label("", 50, UI.WHITE)
	_cap2 = UI.label("", 30, UI.GOLD, false)
	for l in [_cap1, _cap2]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_constant_override("outline_size", 14)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		box.add_child(l)
	_intro_root.add_child(box)
	var skip := UI.button("Überspringen ›", _end_intro, "dark", 24)
	skip.name = "Skip"
	skip.anchor_left = 1.0
	skip.anchor_right = 1.0
	skip.offset_left = -300
	skip.offset_right = -40
	skip.offset_top = 40
	skip.offset_bottom = 110
	_intro_root.add_child(skip)
	_intro_i = -1
	_intro_t = INTRO_STEP
	Music.set_mood("menu")


func _end_intro() -> void:
	P.d.intro_seen = true
	P.mark()
	_intro_i = -1
	hide_menu()


func _intro_frame(dt: float) -> void:
	var w = G.main.world
	_intro_t += dt
	var bh := minf(_intro_t * 400.0, 110.0) if _intro_i <= 0 else 110.0
	(_bars[0] as ColorRect).offset_bottom = bh
	(_bars[1] as ColorRect).offset_top = -bh
	if _intro_t >= INTRO_STEP:
		_intro_t = 0.0
		_intro_i += 1
		if _intro_i >= INTRO.size():
			_end_intro()
			return
		var e: Array = INTRO[_intro_i]
		_cap1.text = e[0]
		_cap2.text = e[1] if _intro_i < INTRO.size() - 1 else P.bunker_name()
		if _intro_i == INTRO.size() - 1:
			_cap2.add_theme_font_size_override("font_size", 64)
		_cap1.modulate.a = 0.0
		_cap2.modulate.a = 0.0
		UI.sfx("bubble_show", "", -12.0)
	var k := _intro_t / INTRO_STEP
	_cap1.modulate.a = clampf(minf(k * 4.0, (1.0 - k) * 5.0), 0.0, 1.0)
	_cap2.modulate.a = clampf(minf(k * 4.0 - 0.6, (1.0 - k) * 5.0), 0.0, 1.0)
	if w == null or w.cam == null or _intro_i < 0:
		return
	var e2: Array = INTRO[_intro_i]
	var c: Vector3 = _bunker_pos() + (e2[2] as Vector3)
	w.cam.override_target = c
	w.cam.yaw_off = lerpf(w.cam.yaw_off, float(e2[3]) + k * 0.35, 1.0 - exp(-dt * 1.5))
	w.cam.pitch_off = lerpf(w.cam.pitch_off, float(e2[4]), 1.0 - exp(-dt * 1.5))
	w.cam.dist = lerpf(w.cam.dist, float(e2[5]) - k * 3.0, 1.0 - exp(-dt * 1.2))


func _bunker_pos() -> Vector3:
	var w = G.main.world
	if w != null and w.get("bunker_node") != null and is_instance_valid(w.bunker_node):
		return w.bunker_node.global_position
	return Vector3.ZERO


func _process(dt: float) -> void:
	if not visible:
		return
	_t += dt
	if is_intro:
		_intro_frame(dt)
		return
	if _title != null and is_instance_valid(_title):
		_title.pivot_offset = _title.size * 0.5
		var sc := 1.0 + sin(_t * 1.6) * 0.015
		_title.scale = Vector2(sc, sc)
		_title.rotation = sin(_t * 0.9) * 0.01
	var w = G.main.world
	if w != null and w.cam != null:
		w.cam.override_target = _bunker_pos() + Vector3(-8, 0, 4)
		w.cam.yaw_off += dt * 0.06
		w.cam.pitch_off = lerpf(w.cam.pitch_off, -0.15, 1.0 - exp(-dt))
		w.cam.dist = lerpf(w.cam.dist, 38.0, 1.0 - exp(-dt))


func _unhandled_input(event: InputEvent) -> void:
	if visible and is_intro and event.is_pressed() and (event is InputEventKey and (event.keycode == KEY_ESCAPE or event.keycode == KEY_SPACE)):
		_end_intro()
		get_viewport().set_input_as_handled()
